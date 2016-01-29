#!/usr/bin/perl
use Modern::Perl;
use GD;
use Data::Dumper;
use Getopt::Std;
use File::Basename;

our %colors = (
                "FFC0C0" => [0,0], "FF0000" => [0,1], "C00000" => [0,2],
                "FFFFC0" => [1,0], "FFFF00" => [1,1], "C0C000" => [1,2],
                "C0FFC0" => [2,0], "00FF00" => [2,1], "00C000" => [2,2],
                "C0FFFF" => [3,0], "00FFFF" => [3,1], "00C0C0" => [3,2],
                "C0C0FF" => [4,0], "0000FF" => [4,1], "0000C0" => [4,2],
                "FFC0FF" => [5,0], "FF00FF" => [5,1], "C000C0" => [5,2],
                "FFFFFF" => [-1,-1], "000000" => [-1,-1],
             );

our @dp = qw/r d l u/;

our $dpval = 0;
our $ccval = 0;
our @list;
our @hold;
our @bound;
our @stack = ();
our %codels = ();
our %opt = ();
#                y,x
my ($cy, $cx) = (0,0); 
my ($ny, $nx) = (0,0);
my ($ty, $tx) = (0,0);
my $count = 0;
my $bail = 0;
my $toggle = 0;
my $im;
my $dir;
our $tr;
my $trace = 60;
#my $trace = 100;

getopts('dt', \%opt);

if ($opt{d}) {
    open (DEBUG, '>', "pietdebug.out") or die ("Can't create pietdebug.out: $!\n");
    print DEBUG "DEBUG enabled\n";
}

my $image = shift;

if (!$image) {
    my $prog = basename($0);
    
    print "USAGE\n";
    print "  $prog [options] imagefile\n\n";
    print "DESCRIPTION\n";
    print "  Piet Interpreter written in Perl\n\n";
    print "OPTIONS\n";
    print "  -d           Debug Statistics File output\n";
    print "  -t           Trace Execution Image output\n\n";
    print "OPERANDS\n";
    print "  imagefile    path to input image file\n\n";
    print "FILES\n";
    print "  Output files (-d,-t,...) written to current directory\n";
    print "  Debug (-d) file name is pietdebug.out\n";
    print "  Trace (-t) file name is imagefile-trace.png\n\n";
    print "EXAMPLES\n";
    print "  $prog ./Examples/hi.png\n";
    print "  $prog -d -t helloworld.gif\n\n";
    
    exit(1);
}

if ($image =~ m/\S+\.png$/i) {
    if ($opt{d}) { print DEBUG "\$im created from png\n"; }
    $im = newFromPng GD::Image($image);
} elsif ($image =~ m/\S+\.gif$/i) {
    if ($opt{d}) { print DEBUG "\$im created from gif\n"; }
    $im = newFromGif GD::Image($image);
} else {
    print "Error: Unsupported Image Format\n";
    exit(1);
}

my ($w, $h) = $im->getBounds();

my $size = codelsize($im, $w, $h);
if ($opt{d}) { print DEBUG "codelsize calculated: $size\n"; }

@list = extractcolors($im, $w, $h, $size);
if ($opt{d}) {
    print DEBUG "Colors Extracted: \n";
    #print DEBUG Dumper \@list;
}

sanitize();
if ($opt{d}) {
    print DEBUG "Colors Sanitized: \n";
    #print DEBUG Dumper \@list;
}

if ($opt{d}) {
    #outimage($image, 40);
}
#exit(0);

#if ($opt{t}) { preparetrace($trace); }

while ($count < 5000) {
    if ($bail > 8) {
        print "\nProgram Terminated: Exit Block\n";
        if ($opt{d}) {
            print DEBUG "Program Terminated: Exit Block\n";
            close (DEBUG);
        }
        #if ($opt{t}) { endtrace($image); }
        exit(0);
    }
    
    if ($opt{d}) { printf DEBUG "Step #%d\n", $count + 1; }
    
    @hold = ();
    @bound = ();
    $dir = $dp[$dpval];
    
    if ($opt{d}) { print DEBUG "currentdp=($dir), currentcc=($ccval)\n"; }
    
    ($cy, $cx) = getedge($cy, $cx, $list[$cy][$cx]);
    
    ($ny, $nx) = getnext($dir, $cy, $cx);
    
    if (!valid($ny, $nx)) {
        if ($toggle) {
            dopoint(1);
            $toggle = 0;
        } else {
            doswitch(1);
            $toggle = 1;
        }
        
        $bail++;
        next;
    } elsif (white($ny, $nx)) {
        if ($opt{d}) { print DEBUG "White Path Traced\n"; }
        
        ($cy, $cx) = tracewhite($cy, $cx, $ny, $nx, $trace);
        $bail = 0;
    } else {
        if ($opt{d}) { print DEBUG "current=($cy,$cx) : next=($ny,$nx)\n"; }
        
        @hold = ();
        
        decideop($cy, $cx, $ny, $nx, $trace);
        
        ($cy, $cx) = ($ny, $nx);
        $bail = 0;
        $toggle = 0;
    }
    
    $count++;
    
    if ($opt{d}) {
        print DEBUG "Current Stack Contents: \n";
        print DEBUG Dumper \@stack;
    }
}

#if ($opt{t}) { endtrace($image); }

print "\nProgram Terminated: Step Escape\n";
exit(0);

#==================SUBROUTINES==========================

sub decideop {
    my ($cy, $cx, $ny, $nx, $i) = @_;
    
    my $color = $list[$cy][$cx];
    my $other = $list[$ny][$nx];
    
    my ($hue, $light) = colorchange($color, $other);
    
    for ($light) {
        when (0) {
            for ($hue) {
                when (0) {}
                when (1) {
                    if ($opt{d}) { print DEBUG "doadd()\n"; }
                    #if ($opt{t}) { traceop($cy, $cx, $ny, $nx, $i, "add"); }
                    doadd();
                }
                when (2) {
                    if ($opt{d}) { print DEBUG "dodiv()\n"; }
                    #if ($opt{t}) { traceop($cy, $cx, $ny, $nx, $i, "div"); }
                    dodiv();
                }
                when (3) {
                    if ($opt{d}) { print DEBUG "dogreat()\n"; }
                    #if ($opt{t}) { traceop($cy, $cx, $ny, $nx, $i, "great"); }
                    dogreat();
                }
                when (4) {
                    if ($opt{d}) { print DEBUG "dodup()\n"; }
                    #if ($opt{t}) { traceop($cy, $cx, $ny, $nx, $i, "dup"); }
                    dodup();
                }
                when (5) {
                    if ($opt{d}) { print DEBUG "doin(1)\n"; }
                    #if ($opt{t}) { traceop($cy, $cx, $ny, $nx, $i, "inC"); }
                    doin(1);
                }
            }
        }
        when (1) {
            for ($hue) {
                when (0) {
                    my $block = blocksize($cy, $cx, $list[$cy][$cx]);
                    if ($opt{d}) { print DEBUG "dopush($block)\n"; }
                    #if ($opt{t}) { traceop($cy, $cx, $ny, $nx, $i, "push($block)"); }
                    dopush($block);
                }
                when (1) {
                    if ($opt{d}) { print DEBUG "dosub()\n"; }
                    #if ($opt{t}) { traceop($cy, $cx, $ny, $nx, $i, "sub"); }
                    dosub();
                }
                when (2) {
                    if ($opt{d}) { print DEBUG "domod()\n"; }
                    #if ($opt{t}) { traceop($cy, $cx, $ny, $nx, $i, "mod"); }
                    domod();
                }
                when (3) {
                    if ($opt{d}) { print DEBUG "dopoint()\n"; }
                    #if ($opt{t}) { traceop($cy, $cx, $ny, $nx, $i, "point"); }
                    dopoint();
                }
                when (4) {
                    if ($opt{d}) { print DEBUG "doroll()\n"; }
                    #if ($opt{t}) { traceop($cy, $cx, $ny, $nx, $i, "roll"); }
                    doroll();
                }
                when (5) {
                    if ($opt{d}) { print DEBUG "doout(0)\n"; }
                    #if ($opt{t}) { traceop($cy, $cx, $ny, $nx, $i, "outI"); }
                    doout(0);
                }
            }
        }
        when (2) {
            for ($hue) {
                when (0) {
                    if ($opt{d}) { print DEBUG "dopop()\n"; }
                    #if ($opt{t}) { traceop($cy, $cx, $ny, $nx, $i, "pop"); }
                    dopop();
                }
                when (1) {
                    if ($opt{d}) { print DEBUG "domul()\n"; }
                    #if ($opt{t}) { traceop($cy, $cx, $ny, $nx, $i, "mul"); }
                    domul();
                }
                when (2) {
                    if ($opt{d}) { print DEBUG "donot()\n"; }
                    #if ($opt{t}) { traceop($cy, $cx, $ny, $nx, $i, "not"); }
                    donot();
                }
                when (3) {
                    if ($opt{d}) { print DEBUG "doswitch()\n"; }
                    #if ($opt{t}) { traceop($cy, $cx, $ny, $nx, $i, "switch"); }
                    doswitch();
                }
                when (4) {
                    if ($opt{d}) { print DEBUG "doin(0)\n"; }
                    #if ($opt{t}) { traceop($cy, $cx, $ny, $nx, $i, "inI"); }
                    doin(0);
                }
                when (5) {
                    if ($opt{d}) { print DEBUG "doout(1)\n"; }
                    #if ($opt{t}) { traceop($cy, $cx, $ny, $nx, $i, "outC"); }
                    doout(1);
                }
            }
        }
    }
}

sub blocksize {
    no warnings 'recursion';
    
    my ($y, $x, $color) = @_;
    my $temp;
    my $val = 1;
    
    my $pix = sprintf "%d,%d", $y,$x;
    push(@hold, $pix);
    
    $pix = sprintf "%d,%d", $y, $x + 1;
    if ($x + 1 < @{$list[0]} && !grep {$_ eq ($pix)} @hold) {
        $temp = $list[$y][$x + 1];
        if ($temp ~~ $color) { $val += blocksize($y, $x + 1, $color); }
    }
    
    $pix = sprintf "%d,%d", $y+1, $x;
    if ($y + 1 < @list && !grep {$_ eq ($pix)} @hold) {
        $temp = $list[$y + 1][$x];
        if ($temp ~~ $color) { $val += blocksize($y + 1, $x, $color); }
    }
    
    $pix = sprintf "%d,%d", $y, $x - 1;
    if ($x - 1 >= 0 && !grep {$_ eq ($pix)} @hold) {
        $temp = $list[$y][$x - 1];
        if ($temp ~~ $color) { $val += blocksize($y, $x - 1, $color); }
    }
    
    $pix = sprintf "%d,%d", $y - 1, $x;
    if ($y - 1 >= 0 && !grep {$_ eq ($pix)} @hold) {
        $temp = $list[$y - 1][$x];
        if ($temp ~~ $color) { $val += blocksize($y - 1, $x, $color); }
    }
    
    return $val;
}

sub colorchange {
    my ($a, $b) = @_;
    my ($fhue, $flight) = @{$colors{$a}};
    my ($shue, $slight) = @{$colors{$b}};
    
    my $outh = differ($fhue, $shue, 6);
    my $outl = differ($flight, $slight, 3);
    
    return ($outh, $outl);
}

sub differ {
    my ($a, $b, $index) = @_;
    my $out;
    
    if ($b >= $a) { $out = $b - $a; } else { $out = ($b - $a) % $index; }
    
    return $out;
}

sub tracewhite {
    my ($cy, $cx, $y, $x, $i) = @_;
    my ($tmpy, $tmpx) = ($y, $x);
    my $dir = $dp[$dpval];
    my ($ny, $nx) = (0,0);
    my $out = 0;
    my $bail = 0;
    
    #if ($opt{t}) {
    #    traceline($cy, $cx, $tmpy, $tmpx, $i);
    #    traceop($cy, $cx, $tmpy, $tmpx, $i, "no-op");
    #    tracedot($tmpy, $tmpx, $i);
    #}
    
    while (!$out) {
        $dir = $dp[$dpval];
        ($ny, $nx) = getnext($dir, $tmpy, $tmpx);
        
        if ($opt{d}) { print DEBUG "current = ($ny,$nx)\n"; }
        
        if ($bail) {
            print "\nProgram Terminated: Unescapable White Path\n";
            if ($opt{d}) {
                print DEBUG "Program Terminated: Unescapable White Path\n";
                close (DEBUG);
            }
            exit(1);
        }
        
        if (!valid($ny, $nx)) {
            doswitch(1);
            dopoint(1);
            
            if ($opt{d}) { print DEBUG "shifting direction - obstacle\n"; }
            #if ($opt{t}) { tracedot($tmpy, $tmpx, $i); }
        } elsif ($list[$ny][$nx] ~~ "FFFFFF") {
            #if ($opt{t}) { traceline($tmpy, $tmpx, $ny, $nx, $i); }
            if ($opt{d}) { print DEBUG "keep going\n"; }
            
            ($tmpy, $tmpx) = ($ny, $nx);
        } else {
            $out = 1;
            
            if ($opt{d}) { print DEBUG "found what we want\n"; }
            #if ($opt{t}) {
            #    tracedot($tmpy, $tmpx, $i);
            #    traceline($tmpy, $tmpx, $ny, $nx, $i);
            #    traceop($tmpy, $tmpx, $ny, $nx, $i, "no-op");
            #}
        }
    }
    
    return ($ny, $nx);
}

sub white {
    my ($y, $x) = @_;
    my $out = 0;
    
    if ($list[$y][$x] ~~ "FFFFFF") { $out = 1; }
    
    return $out;
}

sub valid {
    my ($y, $x) = @_;
    my $out = 1;
    
    if ($y < 0 || $y >= @list || $x < 0 || $x >= @{$list[0]} || $list[$y][$x] ~~ "000000") {
        $out = 0;
    }
    
    return $out;
}

sub getnext {
    my ($dir, $y, $x) = @_;
    
    for ($dir) {
        when ('r') { $x++; }
        when ('d') { $y++; }
        when ('l') { $x--; }
        when ('u') { $y--; }
    }
    
    return ($y, $x);
}

sub getedge {
    my ($y, $x, $color) = @_;
    my $dir = $dp[$dpval];
    
    getboundary($y, $x, $color);
    getcorners();
    
    if ($opt{d}) {
        print DEBUG "Corners Determined: \n";
        print DEBUG Dumper \%codels;
    }
    
    my ($outy, $outx) = ($codels{$dir}[$ccval] =~ /^(\d+)\,(\d+)$/);
    
    return ($outy, $outx);
}

sub getcorners {
    my $nimx = 9999;
    my $nimy = 9999;
    my $xamx = 0;
    my $xamy = 0;
    my $min = 9999;
    my $max = 0;
    my @tmpx;
    my @tmpy;
    my @right;
    my @down;
    my @left;
    my @up;

    for my $item (@bound) {
        @tmpx = ($item =~ /\,(\d*)$/);
        @tmpy = ($item =~ /(\d*)\,/);
        $nimx = $tmpx[0] < $nimx ? $tmpx[0] : $nimx;
        $nimy = $tmpy[0] < $nimy ? $tmpy[0] : $nimy;
        $xamx = $tmpx[0] >= $xamx ? $tmpx[0] : $xamx;
        $xamy = $tmpy[0] >= $xamy ? $tmpy[0] : $xamy;
    }
    for my $item (@bound) {
        if ($item =~ /\,\Q$xamx/) { push @right, $item; }
        if ($item =~ /^\Q$xamy\E\,/) { push @down, $item; }
        if ($item =~ /\,\Q$nimx\E$/) { push @left, $item; }
        if ($item =~ /^\Q$nimy\E\,/) { push @up, $item; }
    }
    
    for my $item (@right) {
        @tmpy = ($item =~ /(\d*)\,/);
        $min = $tmpy[0] < $min ? $tmpy[0] : $min;
        $max = $tmpy[0] >= $max ? $tmpy[0] : $max;
    }
    for my $item (@right) {
        if ($item ~~ "$min,$xamx") { $codels{'r'}[0] = $item; }
        if ($item ~~ "$max,$xamx") { $codels{'r'}[1] = $item; }
    }
    
    $min = 9999;
    $max = 0;
    
    for my $item (@down) {
        @tmpx = ($item =~ /\,(\d*)$/);
        $min = $tmpx[0] < $min ? $tmpx[0] : $min;
        $max = $tmpx[0] >= $max ? $tmpx[0] : $max;
    }
    for my $item (@down) {
        if ($item ~~ "$xamy,$min") { $codels{'d'}[1] = $item; }
        if ($item ~~ "$xamy,$max") { $codels{'d'}[0] = $item; }
    }
    
    $min = 9999;
    $max = 0;
    
    for my $item (@left) {
        @tmpy = ($item =~ /(\d*)\,/);
        $min = $tmpy[0] < $min ? $tmpy[0] : $min;
        $max = $tmpy[0] >= $max ? $tmpy[0] : $max;
    }
    for my $item (@left) {
        if ($item ~~ "$min,$nimx") { $codels{'l'}[1] = $item; }
        if ($item ~~ "$max,$nimx") { $codels{'l'}[0] = $item; }
    }
    
    $min = 9999;
    $max = 0;
    
    for my $item (@up) {
        @tmpx = ($item =~ /\,(\d*)$/);
        $min = $tmpx[0] < $min ? $tmpx[0] : $min;
        $max = $tmpx[0] >= $max ? $tmpx[0] : $max;
    }
    for my $item (@up) {
        if ($item ~~ "$nimy,$min") { $codels{'u'}[0] = $item; }
        if ($item ~~ "$nimy,$max") { $codels{'u'}[1] = $item; }
    }
}

sub getboundary {
    no warnings 'recursion';
    my ($y, $x, $color) = @_;
    my $temp;
    my $pix;
    
    $pix = sprintf "%d,%d", $y, $x;
    
    unless (surrounded($y, $x, $color)) { push(@bound, $pix); }
    push(@hold, $pix);
    
    $pix = sprintf "%d,%d", $y, $x + 1;
    if ($x + 1 < @{$list[0]} && !grep {$_ eq ($pix)} @hold) {
        $temp = $list[$y][$x + 1];
        if ($temp ~~ $color) { getboundary($y, $x + 1, $color); }
    }
    
    $pix = sprintf "%d,%d", $y + 1, $x;
    if ($y + 1 < @list && !grep {$_ eq ($pix)} @hold) {
        $temp = $list[$y + 1][$x];
        if ($temp ~~ $color) { getboundary($y + 1, $x, $color); }
    }
    
    $pix = sprintf "%d,%d", $y, $x - 1;
    if ($x - 1 >= 0 && !grep {$_ eq ($pix)} @hold) {
        $temp = $list[$y][$x - 1];
        if ($temp ~~ $color) { getboundary($y, $x - 1, $color); }
    }
    
    $pix = sprintf "%d,%d", $y - 1, $x;
    if ($y - 1 >= 0 && !grep {$_ eq ($pix)} @hold) {
        $temp = $list[$y - 1][$x];
        if ($temp ~~ $color) { getboundary($y - 1, $x, $color); }
    }
}

sub surrounded {
    my ($y, $x, $col) = @_;
    my $out = 0;
    my $clmn = @{$list[0]};
    my $row = @list;
    
    if ($x + 1 < $clmn && $y + 1 < $row &&
        $x - 1 >= 0    && $y - 1 >= 0   )
    {
        if ($col ~~ $list[$y][$x + 1] && $col ~~ $list[$y + 1][$x] &&
            $col ~~ $list[$y][$x - 1] && $col ~~ $list[$y - 1][$x])
        {
            $out = 1;
        }
    }
    
    return $out;
}

sub preparetrace {
    my ($i) = @_;
    my $h = @list * $i;
    my $w = @{$list[0]} * $i;
    $tr = new GD::Image($w, $h);
    
    foreach my $y (0 .. @list - 1) {
        foreach my $x (0 .. @{$list[0]} - 1) {
            my $color = $tr->colorResolve(hextorgb($list[$y][$x]));
            $tr->filledRectangle($x * $i, $y * $i, ($x + 1) * $i, ($y + 1) * $i, $color);
        }
    }
}

sub tracedot {
    my ($y, $x, $i) = @_;
    
    my $black = $tr->colorResolve(000,000,000);
    $tr->filledArc(($x + 0.5) * $i, ($y + 0.5) * $i, $i / 5, $i / 5, 0, 360, $black);
}

sub traceline {
    my ($ya, $xa, $yb, $xb, $i) = @_;
    
    my $black = $tr->colorResolve(000,000,000);
    $tr->line(($xa + 0.5) * $i, ($ya + 0.5) * $i, ($xb + 0.5) * $i, ($yb + 0.5) * $i, $black);
}

sub traceop {
    #TODO - streamline traceop - center text
    
    my ($ya, $xa, $yb, $xb, $i, $op) = @_;
    my $black = $tr->colorResolve(000,000,000);
    
    my $adjust = 0.7;
    my $hold = 0.6;
    
    if ($ya == $yb) {
        if ($xa > $xb) {
            if ($i >= 100) { $adjust = 0.8; }
            if (length $op == 3) { $adjust = 0.9; }
            if (length $op == 4) { $adjust = 0.85; }
            
            $tr->string(gdSmallFont, ($xb + $adjust) * $i, ($ya + $hold) * $i, $op, $black);
        } else {
            if ($i >= 100) { $adjust = 0.8; }
            if (length $op == 3) { $adjust = 0.9; }
            if (length $op == 4) { $adjust = 0.85; }
            
            $tr->string(gdSmallFont, ($xa + $adjust) * $i, ($ya + $hold) * $i, $op, $black);
        }
    }
    
    if ($xa == $xb) {
        if ($ya > $yb) {
            $tr->string(gdSmallFont, ($xa + $hold) * $i, ($ya - $adjust) * $i, $op, $black);
        } else {
            $adjust = 0.1;
            $hold = 0.25;
            if ($i >= 100) { $hold = 0.3; }
            if (length $op == 3) { $hold = 0.4; }
            if (length $op == 4) { $hold = 0.35; }
            
            $tr->string(gdSmallFont, ($xa + $hold) * $i, ($yb - $adjust) * $i, $op, $black);
        }
    }
}

sub endtrace {
    my ($image) = @_;
    
    $image =~ /(\S+)\./;
    $image = $1 . "-trace.png";
    
    open (OUT, '>', $image) or die ("Can't create $image: $!\n");
    binmode (OUT);
    print OUT $tr->png;
    close (OUT);
}

sub sanitize {
    my $temp;
    
    foreach my $y (0 .. @list - 1) {
        foreach my $x (0 .. @{$list[0]} - 1) {
            if (exists $colors{$list[$y][$x]}) { next; }
        
            $temp = closestcolor($list[$y][$x]);
            
            if (not exists $colors{$temp}) {
                print "\nProgram Termination: Invalid Color Detected\n";
                if ($opt{d}) {
                    print DEBUG "Program Termination: Invalid Color Detected\n";
                    close (DEBUG);
                }
                exit(1);
            }
            
            $list[$y][$x] = $temp;
        }
    }
}

sub closestcolor {
    my ($col) = @_;
    
    my @rgb = hextorgb($col);
    
    for my $i (0 .. @rgb - 1) {
        if (255 - $rgb[$i] <= 10)      { $rgb[$i] = 255; next; }
        if (abs(10 - $rgb[$i]) <= 10)  { $rgb[$i] =   0; next; }
        if (abs(192 - $rgb[$i]) <= 10) { $rgb[$i] = 192; next; }
    }
    
    my $out = rgbtohex($rgb[0], $rgb[1], $rgb[2]);
    
    return $out;
}

sub codelsize {
    my ($im, $w, $h) = @_;
    my $store = 0;
    my $count;

    foreach my $y (0 .. $h - 1) {
        $count = 1;
        
        foreach my $x (0 .. $w - 1) {
            my $first = $im->getPixel($x, $y);
            my $second = $im->getPixel($x + 1, $y);
            
            if ($first == $second) {
                $count++;
            } else {
                if (!$store || $count <= $store) { $store = $count; }
                $count = 1;
            }
        }
        
        if ($store == 1) { last; }
    }
    
    return $store;
}

sub extractcolors {
    my ($im, $w, $h, $size) = @_;
    my @out;
    
    for (my $x = 0; $x < $w; $x += $size) {
        for (my $y = 0; $y < $h; $y += $size) {
            $out[$y/$size][$x/$size] = rgbtohex($im->rgb($im->getPixel($x,$y)));
        }
    }
    
    return @out;
}

sub rgbtohex {
    my ($r, $g, $b) = @_;
    return sprintf("%02X%02X%02X", $r, $g, $b);
}

sub hextorgb {
    my ($s) = @_;
    my $r = hex(substr ($s, 0, 2));
    my $g = hex(substr ($s, 2, 2));
    my $b = hex(substr ($s, 4));
    
    return ($r, $g, $b);
}

sub outimage {
    my ($image, $i) = @_;
    my $h = @list * $i;
    my $w = @{$list[0]} * $i;
    my $out = new GD::Image($w, $h);
    
    foreach my $y (0 .. @list - 1) {
        foreach my $x (0 .. @{$list[0]} - 1) {
            my $color = $out->colorResolve(hextorgb($list[$y][$x]));
            $out->filledRectangle($x * $i, $y * $i, ($x + 1) * $i, ($y + 1) * $i, $color);
        }
    }
    
    $image =~ /(\S+)\./;
    $image = $1 . "BIG.png";
    
    open (OUTE, '>', $image) or die ("Can't Create $image: $!\n");
    binmode (OUTE);
    print OUTE $out->png;
    close (OUTE);
    
    if ($opt{d}) { print DEBUG "$image created\n"; }
}

sub dopush {
    my ($val) = @_;
    push (@stack, $val);
}

sub dopop { return pop @stack; }

sub doadd {
    my $one = dopop();
    my $two = dopop();
    
    if (!$one || !$two) {
        if ($opt{d}) { print DEBUG "Error:doadd: adding with undefined stack elements\n"; }
    } else {
        dopush($one + $two);
    }
}

sub dosub {
    my $one = dopop();
    my $two = dopop();
    
    if (!$one || !$two) {
        if ($opt{d}) { print DEBUG "Error:dosub: subtracting with undefined stack elements\n"; }
    } else {
        dopush($two - $one);
    }
}

sub domul {
    my $one = dopop();
    my $two = dopop();
    
    if (!$one || !$two) {
        if ($opt{d}) { print DEBUG "Error:domul: multiplying with undefined stack elements\n"; }
    } else {
        dopush($one * $two);
    }
}

sub dodiv {
    my $one = dopop();
    my $two = dopop();
    
    if (!$one || !$two) {
        if ($opt{d}) { print DEBUG "Error:dodiv: dividing with invalid stack elements\n"; }
    } else {
        dopush(int($two / $one));
    }
}

sub domod {
    my $one = dopop();
    my $two = dopop();
    
    if (!$one || !$two) {
        if ($opt{d}) { print DEBUG "Error:domod: modulus with invalid stack elements\n"; }
    } else {
        dopush($two % $one);
    }
}

sub donot {
    my $one = dopop();
    my $res = 0;
    
    if (defined $one && $one == 0) { $res = 1; }
    dopush($res);
}

sub dogreat {
    my $one = dopop();
    my $two = dopop();
    my $res = 0;
    
    if (defined $one && defined $two && $two > $one) { $res = 1; }
    dopush($res);
}

sub dopoint {
    my $i;
    
    if (@_) {
        ($i) = @_;
        if ($i !~ m/^\-?[0-9]+$/) {
            if ($opt{d}) { print DEBUG "Error:dopoint: argument not integer\n"; }
            $i = 0;
        }
    } else {
        $i = dopop();
        if (not defined $i) {
            if ($opt{d}) { print DEBUG "Error:dopoint: dp not adjusted\n"; }
            $i = 0;
        }
    }
    
    $dpval = ($dpval + $i) % @dp;
}

sub doswitch {
    my $i;
    
    if (@_) {
        ($i) = @_;
        if ($i !~ m/^\-?[0-9]+$/) {
            if ($opt{d}) { print DEBUG "Error:doswitch: argument not integer\n"; }
            $i = 0;
        }
    } else {
        $i = dopop();
        if (not defined $i) {
            if ($opt{d}) { print DEBUG "Error:doswitch: cc not adjusted\n"; }
            $i = 0;
        }
    }
    
    $i = abs($i);
    
    for (0 .. $i - 1) { $ccval = (!$ccval eq '') ? 0 : 1; }
}

sub dodup {
    my $one = dopop();
    
    if (defined $one) {
        dopush($one);
        dopush($one);
    }
}

sub doroll {
    my $i = dopop();
    my $depth = dopop();
    
    if ($i && $depth) {
        if (@stack - $depth < 0) {
            if ($opt{d}) {
                print DEBUG "Error:doroll: roll not performed\n";
                print DEBUG "depth larger than viable stack\n";
            }
        } else {
            my $start = @stack - $depth;
            my @hold = @stack[$start .. @stack - 1];
        
            for (0 .. $i - 1) { unshift (@hold, pop @hold); }
            splice (@stack, $start, @hold, @hold);
        }
    } else {
        if ($opt{d}) {
            print DEBUG "Error:doroll: roll not performed\n";
            print DEBUG "0 iterations\n" if (!$i);
            print DEBUG "0 depth\n" if (!$depth);
        }
    }
}

sub doin {
    my ($mode) = @_;
    print "?";
    chomp (my $val = <>);
    
    if (not defined $val) {
        if ($opt{d}) { print DEBUG "Error:doin: no input found\n"; }
    } else {
        if ($mode) {
            if ($val !~ m/[A-z]/) {
                if ($opt{d}) { print DEBUG "Error:doin: input not character\n"; }
            } else {
                if (length $val > 1) {
                    if ($opt{d}) { print DEBUG "More than one character detected - inputting first character\n"; }
                }
                
                $val = substr($val,0,1);
                dopush(ord $val);
            }
        } else {
            if ($val !~ m/^\-?[0-9]+$/) {
                if ($opt{d}) { print DEBUG "Error:doin: input not number\n"; }
            } else {
                dopush(int($val));
            }
        }
    }
}

sub doout {
    my ($mode) = @_;
    my $val = dopop();
    
    if (not defined $val) {
        if ($opt{d}) { print DEBUG "Error:doout: nothing to output\n"; }
    } else {
        if ($mode) {
            if ($opt{d}) { printf DEBUG "Output: %s\n", chr $val; }
            print chr $val;
        } else {
            if ($opt{d}) { print DEBUG "Output: $val\n"; }
            print $val;
        }
    }
}