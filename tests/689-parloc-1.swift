
import io;

@par @dispatch=WORKER (void  v) f_init(int n) "f" "0.0" "f_init_tcl";

@location=0 @par=2 f_init(10);
