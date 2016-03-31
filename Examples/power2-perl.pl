doinI(2
);
doinI(3
);
dodup();
dopush(1);
dopush(1);
dosub();
dogreat();
donot();
dopop();
dopush(2);
dopush(1);
doroll();
dodup();
dopush(3);
dopush(2);
doroll();
dodup();
dopush(1);
dogreat();
dopop();
dopush(1);
dosub();
dopush(3);
dopush(2);
doroll();
dodup();
dopush(4);
dopush(3);
doroll();
domul();
dopush(3);
dopush(2);
doroll();
dodup();
dopush(1);
dogreat();
dopop();
dopush(1);
dosub();
dopush(3);
dopush(2);
doroll();
dodup();
dopush(4);
dopush(3);
doroll();
domul();
dopush(3);
dopush(2);
doroll();
dodup();
dopush(1);
dogreat();
dopop();
dopush(3);
dopush(2);
doroll();
dopop();
dopop();
dooutI();
sub dogreat {
    $one = pop(@stack);
    $two = pop(@stack);
    $res = (defined $one && defined $two && $two > $one) ? 1 : 0;
    push(@stack, $res);
}
sub dodup {
    $one = pop(@stack);
    if (defined $one) {
        push(@stack, $one);
        push(@stack, $one);
    }
}
sub dopush {
    $val = shift;
    push(@stack, $val);
}
sub dosub {
    $one = pop(@stack);
    $two = pop(@stack);
    unless (not defined $one || not defined $two) { push(@stack, $one - $two); }
};
sub dopop { pop(@stack); }
sub doroll {
    $i = pop(@stack);
    $depth = pop(@stack);
    if ($i && $depth) {
        unless (@stack - $depth < 0) {
            $start = @stack - $depth;
            @held = @stack[$start .. @stack - 1];
            if ($i < 0) {
                for (0 .. abs($i) - 1) { push(@held, shift (@held)); }
            } else {
                for (0 .. $i - 1) { unshift (@held, pop(@held)); }
            }
            splice (@stack, $start, @held, @held);
        }
    }
}
sub dooutI {
    $val = pop(@stack);
    unless (not defined $val) { print $val; }
}
sub domul {
    $one = pop(@stack);
    $two = pop(@stack);
    unless (not defined $one || not defined $two) { push(@stack, $one * $two); }
};
sub donot {
    $one = pop(@stack);
    $res = (defined $one && $one == 0) ? 1 : 0;
    push(@stack, $res);
}
sub doinI {
    $input = shift;
    if ($buffer) {
        $buffer =~ /(\d+).*/;
        $val = (defined $1) ? $1 : "";
        unless ($val ~~ "") {
            push(@stack, int($val));
            $buffer = substr($buffer, length $val);
        }
    } else {
        $val = $input;
        chomp($val);
        unless (not defined $val) {
            $buffer = $val;
            $buffer =~ /(\d+).*/;
            $val = (defined $1) ? $1 : "";
            unless ($val ~~ "") {
                push(@stack, int($val));
                $buffer = substr($buffer, length $val);
            }
        }
    }
}
