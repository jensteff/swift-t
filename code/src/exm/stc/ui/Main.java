
package exm.stc.ui;

import java.io.*;
import java.util.Properties;

import org.antlr.runtime.*;
import org.antlr.runtime.tree.CommonTreeAdaptor;
import org.apache.log4j.*;

import exm.stc.antlr.gen.ExMLexer;
import exm.stc.antlr.gen.ExMParser;
import exm.stc.ast.SwiftAST;
import exm.stc.ast.FilePosition.LineMapping;
import exm.stc.common.Settings;
import exm.stc.common.exceptions.InvalidOptionException;
import exm.stc.common.exceptions.STCRuntimeError;
import exm.stc.common.exceptions.UserException;
import exm.stc.common.util.Misc;
import exm.stc.frontend.ASTWalker;
import exm.stc.ic.SwiftICGenerator;
import exm.stc.tclbackend.TurbineGenerator;

public class Main
{
  static Logger logger = null;

  /**
     Input SwiftScript file name
   */
  static String inputFilename = null;

  /**
     Output Tcl-Turbine file name
   */
  static String outputFilename = null;

  /**
     Time at which the parser started
   */
  static final String timestamp = Misc.timestamp();

  public static void main(String[] args)
  {
    processArguments(args);
    try {
      Settings.initSTCProperties();
    } catch (InvalidOptionException ex) {
      System.err.println("Error setting up options: " + ex.getMessage());
      System.exit(1);
    }
    setupLogging();

    ANTLRInputStream input = setupInput();
    PrintStream output = setupOutput();
    PrintStream icOutput = setupICOutput();
    
    compile(input, output, icOutput);
  }

  
  private static void setupLogging()
  {
    Properties properties = System.getProperties();
    String logfile = properties.getProperty("parser.logfile");
    if (logfile != null && logfile.length() > 0)
      setupLoggingToFile(logfile);
    else
      disableLogging();

    // Even if logging is disabled, this must be valid:
    logger = Logger.getLogger("STC");
  }

  private static void setupLoggingToFile(String logfile)
  {
    Layout layout = new PatternLayout("%-5p %m%n");
    boolean append = false;
    try
    {
      Logger root = Logger.getRootLogger();
      Appender appender = new FileAppender(layout, logfile, append);
      root.addAppender(appender);
      root.setLevel(Level.TRACE);
    }
    catch (IOException e)
    {
      System.out.println(e.getMessage());
      System.exit(ExitCode.ERROR_IO.code());
    }
  }

  /**
     Configures Log4j with enough settings to prevent errors
     Logger level set to WARN
   */
  private static void disableLogging()
  {
    Layout layout = new PatternLayout("%-5p %m%n");
    Appender appender = new ConsoleAppender(layout);
    Logger root = Logger.getRootLogger();
    root.addAppender(appender);
    root.setLevel(Level.WARN);
  }

  public static Logger getLogger()
  {
    return logger;
  }

  static void processArguments(String[] args)
  {
    if (args.length == 2)
    {
      inputFilename = args[0];
      outputFilename = args[1];
    }
    else
    {
      usage();
      System.exit(ExitCode.ERROR_COMMAND.code());
    }
  }

  private static void usage()
  {
    System.out.println("usage: parser <input> <output>");
  }

  static ANTLRInputStream setupInput()
  {
    ANTLRInputStream input = null;
    try
    {
      FileInputStream stream = new FileInputStream(inputFilename);
      input = new ANTLRInputStream(stream);
    }
    catch (IOException e)
    {
      System.out.println("Error opening input Swift file: " +
                                            e.getMessage());
      System.exit(ExitCode.ERROR_IO.code());
    }
    return input;
  }

  static PrintStream setupOutput()
  {
    PrintStream output = null;
    try
    {
      FileOutputStream stream = new FileOutputStream(outputFilename);
      BufferedOutputStream buffer = new BufferedOutputStream(stream);
      output = new PrintStream(buffer);
    }
    catch (IOException e)
    {
      System.out.println("Error opening output file: " +
                                          e.getMessage());
      System.exit(ExitCode.ERROR_IO.code());
    }
    return output;
  }

  static PrintStream setupICOutput()
  {
    String icFileName = Settings.get(Settings.IC_OUTPUT_FILE);
    if (icFileName == null || icFileName.equals("")) {
      return null;
    }
    PrintStream output = null;
    try
    {
      FileOutputStream stream = new FileOutputStream(icFileName);
      BufferedOutputStream buffer = new BufferedOutputStream(stream);
      output = new PrintStream(buffer);
    }
    catch (IOException e)
    {
      System.out.println("Error opening IC output file " + icFileName
                      + ": " + e.getMessage());
      System.exit(ExitCode.ERROR_IO.code());
    }
    return output;
  }

  /**
     Use ANTLR to parse the input and get the Tree
   * @throws IOException 
   */
  static SwiftAST runANTLR(ANTLRInputStream input, LineMapping lineMap)
  {
    logger.info("ExM parser starting: " + timestamp);

    ExMLexer lexer = new ExMLexer(input);
    lexer.lineMap = lineMap;
    CommonTokenStream tokens = new CommonTokenStream(lexer);
    ExMParser parser = new ExMParser(tokens);
    parser.lineMap = lineMap;
    parser.setTreeAdaptor(new SwTreeAdaptor());

    // Launch parsing
    ExMParser.program_return program = null;
    try
    {
      program = parser.program();
    }
    catch (RecognitionException e)
    {
      // This is an internal error
      e.printStackTrace();
      System.out.println("Parsing failed: internal error");
      System.exit(ExitCode.ERROR_INTERNAL.code());
    }
    
    /* NOTE: in some cases the antlr parser will actually recover from
     *    errors, print an error message and continue, generating the 
     *    parse tree that it thinks is most plausible.  This is where
     *    we detect this case.
     */
    if (parser.parserError) {
      // This is a user error
      System.err.println("Error occurred during parsing.");
      System.exit(ExitCode.ERROR_USER.code());
    }

    // Do we actually need this check? -Justin (10/26/2011)
    if (program == null)
      throw new STCRuntimeError("PARSER FAILED!");
   
    
    SwiftAST tree = (SwiftAST) program.getTree();
    
    return tree;
  }

  /**
   * Use the file and line info from c preprocessor to 
   * update SwiftAST
   * @param lexer
   * @param tree
   */
  private static LineMapping parsePreprocOutput(ANTLRInputStream input) {

    /*
     * This function is a dirty hack, but works ok
     * because the C preprocessor output has a very simple output format
     * of 
     * # linenum filename flags
     * 
     * We basically just need the linenum and filename
     * (see http://gcc.gnu.org/onlinedocs/cpp/Preprocessor-Output.html)
     */
    LineMapping posTrack = new LineMapping();
    try {
      ExMLexer lexer = new ExMLexer(input);
      /* 
       * don't emit error messages with bad line numbers:
       * we will emit lexer error messages on the second pass
       */
      lexer.quiet = true;
      Token t = lexer.nextToken();
      while (t.getType() != ExMLexer.EOF) {
        if (t.getChannel() == ExMLexer.CPP) { 
          //System.err.println("CPP token: " + t.getText());
          assert(t.getText().substring(0, 2).equals("# "));
          StreamTokenizer tok = new StreamTokenizer(
                new StringReader(t.getText().substring(2)));
          tok.slashSlashComments(false);
          tok.slashStarComments(false);
          tok.quoteChar('"');
          if (tok.nextToken() != StreamTokenizer.TT_NUMBER) {
            throw new STCRuntimeError("Confused by " +
            		" preprocessor line " + t.getText());
          }
          int lineNum = (int)tok.nval;
          
          if (tok.nextToken() == '"') {
            // Quoted file name with octal escape sequences
            
            // Ignore lines from preprocessor holding information we
            // don't need (these start with "<"
            String fileName = tok.sval;
            if (!fileName.startsWith("<")) {
              posTrack.addPreprocInfo(t.getLine() + 1, 
                                    fileName, lineNum);
            }
          }
        }
        t = lexer.nextToken();
      }
    } catch (IOException e) {
      System.out.println("Error while trying to read preprocessor" +
          " output: " + e.getMessage());
      System.exit(ExitCode.ERROR_IO.code());
    }
    return posTrack;
  }

  public static class SwTreeAdaptor extends CommonTreeAdaptor {
    @Override
    public Object create(Token t) {
      return new SwiftAST(t);
    }
  }

  private static void compile(ANTLRInputStream input, PrintStream output,
          PrintStream icOutput) {
    LineMapping lineMapping = parsePreprocOutput(input);
    input.rewind(); input.reset();
    SwiftAST tree = runANTLR(input, lineMapping);
    ASTWalker walker = new ASTWalker(inputFilename, lineMapping);
    try
    {
      SwiftICGenerator intermediate = new SwiftICGenerator(logger, icOutput);
      walker.walk(intermediate, tree);
      // Optimize, then pass through to turbine generator
      intermediate.optimise();
    
      TurbineGenerator codeGen = new TurbineGenerator(logger, timestamp);
      intermediate.regenerate(codeGen);
    
      String code = codeGen.code();
      output.println(code);
      output.close();
      if (icOutput != null) {
        icOutput.close();
      }
      logger.debug("stc done.");
    }
    catch (UserException e)
    {
      System.err.println("stc error:");
      System.err.println(e.getMessage());
      if (logger.isDebugEnabled())
        logger.debug(Misc.stackTrace(e));
      System.exit(ExitCode.ERROR_USER.code());
    }
    catch (Exception e)
    {
      // Other exception, possibly ParserRuntimeException
      System.err.println("PARSER INTERNAL ERROR");
      System.err.println("Please report this");
      e.printStackTrace();
      System.exit(ExitCode.ERROR_INTERNAL.code());
    }
    catch (AssertionError e) {
      System.err.println("PARSER INTERNAL ERROR");
      System.err.println("Please report this");
      e.printStackTrace();
      System.exit(ExitCode.ERROR_INTERNAL.code());
    }
  }
}
