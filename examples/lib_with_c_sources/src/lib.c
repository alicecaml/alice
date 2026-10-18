#include <caml/mlvalues.h>
#include <stdio.h>

value defined_in_c(value v_unit) {
  (void)v_unit;
  printf("Hello, World!\n");
  return Val_unit;
}
