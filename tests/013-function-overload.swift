// SKIP-THIS-TEST
// COMPILE-ONLY-TEST

f(int a) {
  trace("got an int", a);
}

f(float a) {
  trace("got a float", a);
}

// The argument could be interpreted as an int or float, complicating overload
// resolution
f(1);

f(1.0);
