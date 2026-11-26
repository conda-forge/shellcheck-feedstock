#!/bin/sh
value() { echo ok; }
report() {
    printf 'first %s\n' "$(value)"
    printf 'second %s\n' "$(value)"
}
report
