package exm.stc.common.util;


public class Pair<T1, T2> {
  public final T1 val1;
  public final T2 val2;

  public Pair(T1 first, T2 second) {
    super();
    this.val1 = first;
    this.val2 = second;
  }
  
  public static <T1, T2> Pair<T1, T2> create(T1 f, T2 s) {
    return new Pair<T1, T2>(f, s);
  }
}
