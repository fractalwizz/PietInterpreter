#!/usr/bin/perl
use Modern::Perl;
use GD;
use Data::Dumper;
use Getopt::Std;
use File::Basename;

# color palette
our %colors = (
                "FFC0C0" => [0,0], "FF0000" => [0,1], "C00000" => [0,2],
                "FFFFC0" => [1,0], "FFFF00" => [1,1], "C0C000" => [1,2],
                "C0FFC0" => [2,0], "00FF00" => [2,1], "00C000" => [2,2],
                "C0FFFF" => [3,0], "00FFFF" => [3,1], "00C0C0" => [3,2],
                "C0C0FF" => [4,0], "0000FF" => [4,1], "0000C0" => [4,2],
                "FFC0FF" => [5,0], "FF00FF" => [5,1], "C000C0" => [5,2],
                "FFFFFF" => [-1,-1], "000000" => [-1,-1],
             );

# direction array
our @dp = qw/r d l u/;
our @stack = ();
our %codels = ();
our %opt = ();
our @list;
our @hold;
our @bound;

our $buffer = "";
our $dpval = 0;
our $ccval = 0;
#                y,x
my ($cy, $cx) = (0,0); 
my ($ny, $nx) = (0,0);
my ($ty, $tx) = (-1,-1);
my $bail = 0;
my $toggle = 0;
my $step = 0;
my $dir;

my $im;
our $tr;

# cmd parameters
getopts('dts:c:p:v:', \%opt);

my $trace = $opt{s} || 60;
my $count = $opt{p} || 1;

my $image = shift;

if (!$image) {
    my $prog = basename($0);
    
    print "USAGE\n";
    print "  $prog [options] imagefile\n\n";
    print "DESCRIPTION\n";
    print "  Piet Interpreter written in Perl\n\n";
    print "OPTIONS\n";
    print "  -d         Debug Statistics File output\n";
    print "  -t         Trace Execution Image output\n";
    print "  -s [int]   Trace Image Codel Size (default: 60)\n";
    print "  -c [int]   Codel Size of Image input (default: determined)\n";
    print "  -p [int]   Step Restraint (default: infinite)\n";
    print "  -v [int]   Invalid Color handling (1: terminate) (2: treat as black) (default: treat as white)\n\n";
    print "OPERANDS\n";
    print "  imagefile  path to input image file\n\n";
    print "FILES\n";
    print "  Output files (-d,-t,...) written to current directory\n";
    print "  Debug (-d) file name is imagefile-debug.out\n";
    print "  Trace (-t) file name is imagefile-trace.png\n\n";
    print "EXAMPLES\n";
    print "  $prog ./Examples/hi.png\n";
    print "  $prog -d -t helloworld.gif\n";
    print "  $prog -t -c 3 -p 15 fizzbuzz.png\n";
    
    exit(1);
}

if ($image =~ m/\S+\.png$/i) {
    $im = newFromPng GD::Image($image);
} elsif ($image =~ m/\S+\.gif$/i) {
    $im = newFromGif GD::Image($image);
} else {
    print "Error: Unsupported Image Format\n";
    exit(1);
}

if ($opt{d}) {
    my $fil = $image;
    $fil =~ /(\S+)\./;
    $fil = $1 . "-debug.out";
    
    open (DEBUG, '>', $fil) or die ("Can't create $fil: $!\n");
    print DEBUG "DEBUG enabled\n";
}

my ($w, $h) = $im->getBounds();

# codel size
my $size = $opt{c} || codelsize($im, $w, $h);
if ($opt{d}) { print DEBUG "codelsize calculated: $size\n"; }

# create 2D list of codels
extractcolors($im, $w, $h, $size);
if ($opt{d}) { print DEBUG "Colors Extracted: \n"; }

# clean list
sanitize($image);
if ($opt{d}) {
    print DEBUG "Colors Sanitized: \n";
    #print DEBUG Dumper \@list;
}

if ($opt{t}) {
    preparetrace($trace);
    tracedot($cy, $cx, $trace);
}

# begin interpretation
while ($count) {
    if ($opt{t} && $ty == -1 && $tx == -1) {
        ($ty, $tx) = ($cy, $cx);
    }
    
    # cannot escape codel block
    if ($bail > 8) {
        print "\nProgram Terminated: Exit Block\n";
        
        if ($opt{d}) {
            print DEBUG "Program Terminated: Exit Block\n";
            close (DEBUG);
        }
        if ($opt{t}) { endtrace($image); }
        
        exit(0);
    }
    
    @hold = ();
    @bound = ();
    $dir = $dp[$dpval];
    
    if ($opt{d}) {
        printf DEBUG "\nStep #%d\n", $step + 1;
        print DEBUG "dp=($dir), cc=($ccval)\n";
    }
    
    # codel to move from
    ($cy, $cx) = getedge($cy, $cx, $list[$cy][$cx]);
    
    # codel to move to
    ($ny, $nx) = getnext($dir, $cy, $cx);
    
    if (!valid($ny, $nx)) { # boundary / obstacle
        if ($toggle) {
            dopoint(1);
            $toggle = 0;
        } else {
            doswitch(1);
            $toggle = 1;
        }
        
        $bail++;
        next;
    } elsif (white($ny, $nx)) { # white codel detected - trace path
        if ($opt{d}) { print DEBUG "White Path Trace\n"; }
        if ($opt{t}) {
            traceline($ty, $tx, $cy, $cx, $trace);
            tracedot($cy, $cx, $trace);
            tracedot($ny, $nx, $trace);
            traceline($cy, $cx, $ny, $nx, $trace);
            traceop($cy, $cx, $ny, $nx, $trace, "no-op");
            ($ty, $tx) = (-1, -1);
        }
        
        ($cy, $cx) = tracewhite($ny, $nx, $trace, $image);
        $bail = 0;
        %codels = ();
    } else { # codel of interest - do a thing
        if ($opt{d}) { print DEBUG "($cy,$cx)=>($ny,$nx)\n"; }
        if ($opt{t}) {
            traceline($ty, $tx, $cy, $cx, $trace);
            tracedot($cy, $cx, $trace);
            tracedot($ny, $nx, $trace);
            traceline($cy, $cx, $ny, $nx, $trace);
        }
        
        @hold = ();
        decideop($cy, $cx, $ny, $nx, $trace);
        
        ($cy, $cx) = ($ny, $nx);
        $bail = 0;
        $toggle = 0;
        %codels = ();
        
        if ($opt{t}) { ($ty, $tx) = (-1, -1); }
        
        if ($opt{d}) { printStack(); }
    }
    
    $step++;
    
    if ($opt{p}) { $count--; }
}

if ($opt{t}) { endtrace($image); }

print "\nProgram Terminated: Step Escape\n";
exit(0);

#==================SUBROUTINES==========================

#----------------------------
#-------Initialization-------
#----------------------------

##\
 # Calculates codel size of input image file
 #
 # param: $im: GD image
 # param: $w:  Image width
 # param: $h:  Image height
 #
 # return: codel size
 #/
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

##\
 # Acquires color information from image and stores in 2D list
 #
 # param: $im:   GD image
 # param: $w:    Image width
 # param: $h:    Image height
 # param: $size: codel size
 #/
sub extractcolors {
    my ($im, $w, $h, $size) = @_;
    
    for (my $x = 0; $x < $w; $x += $size) {
        for (my $y = 0; $y < $h; $y += $size) {
            $list[$y / $size][$x / $size] = rgbtohex($im->rgb($im->getPixel($x,$y)));
        }
    }
}

##\
 # Attempts to sanitize input image by converting codels not matching palette
 # to valid colors - Otherwise, (treat as white) or (treat as black) or (terminate)
 #
 # param: $im: file name of input image file
 #/
sub sanitize {
    my ($im) = @_;
    my $temp;
    
    foreach my $y (0 .. @list - 1) {
        foreach my $x (0 .. @{$list[0]} - 1) {
            if (exists $colors{$list[$y][$x]}) { next; }
        
            # attempts to fix color
            $temp = closestcolor($list[$y][$x]);
            
            if (not exists $colors{$temp}) {
				if ($opt{v} == 1) {
                    print "\nProgram Terminated: Invalid Color Detected\n";
                    
                    if ($opt{d}) {
                        print DEBUG "Program Terminated: Invalid Color Detected\n";
                        close (DEBUG);
                    }
                    if ($opt{t}) { endtrace(basename($im));}
                    
                    exit(1);
				} elsif ($opt{v} == 2) {
                    $temp = "000000";
				} else {
                    $temp = "FFFFFF";
				}
            }
            
            $list[$y][$x] = $temp;
        }
    }
}

#----------------------------
#--------Primary Loop--------
#----------------------------

##\
 # Hub to calculate codel to move from in codel block
 #
 # param: $y:     y coordinate of current codel
 # param: $x:     x coordinate of current codel
 # param: $color: codel block color
 #/
sub getedge {
    my ($y, $x, $color) = @_;
    my $dir = $dp[$dpval];
    
    getboundary($y, $x, $color);
    if (!%codels) { getcorners(); }
    
    return @{$codels{$dir}[$ccval]};
}

##\
 # Populates bound array with boundary of relevant codel block
 #
 # param: $y:     y coordinate of codel in codel block
 # param: $x:     x coordinate of codel in codel block
 # param: $color: codel block color
 #/
sub getboundary {
    no warnings 'recursion';
    
    my ($y, $x, $color) = @_;
    my $temp;
    my $pix;
    
    $pix = sprintf("%d,%d", $y, $x);
    
    unless (surrounded($y, $x, $color)) { push(@bound, [$y, $x]); }
    push(@hold, $pix);
    
    # right
    $pix = sprintf("%d,%d", $y, $x + 1);
    if ($x + 1 < @{$list[0]} && !grep {$_ eq ($pix)} @hold) {
        $temp = $list[$y][$x + 1];
        if ($temp ~~ $color) { getboundary($y, $x + 1, $color); }
    }
    
    # down
    $pix = sprintf("%d,%d", $y + 1, $x);
    if ($y + 1 < @list && !grep {$_ eq ($pix)} @hold) {
        $temp = $list[$y + 1][$x];
        if ($temp ~~ $color) { getboundary($y + 1, $x, $color); }
    }
    
    # left
    $pix = sprintf("%d,%d", $y, $x - 1);
    if ($x - 1 >= 0 && !grep {$_ eq ($pix)} @hold) {
        $temp = $list[$y][$x - 1];
        if ($temp ~~ $color) { getboundary($y, $x - 1, $color); }
    }
    
    # up
    $pix = sprintf("%d,%d", $y - 1, $x);
    if ($y - 1 >= 0 && !grep {$_ eq ($pix)} @hold) {
        $temp = $list[$y - 1][$x];
        if ($temp ~~ $color) { getboundary($y - 1, $x, $color); }
    }
}

##\
 # Populates codel hash with left/right corners of codel block
 #
 # Credit to Marc Majcher for his corner determine algorithm
 # Did it the hard way, without ever thinking of using sort...
 # http://cpansearch.perl.org/src/MAJCHER/Piet-Interpreter-0.03/Interpreter.pm
 #/
sub getcorners {
    my @srted = sort {$$b[1] <=> $$a[1]} @bound;
    my @right = sort {$$a[0] <=> $$b[0]} grep {$$_[1] == $srted[0][1]} @srted;
    @{$codels{'r'}} = ($right[0], $right[-1]);

    @srted   = sort {$$b[0] <=> $$a[0]} @bound;
    my @down = sort {$$a[1] <=> $$b[1]} grep {$$_[0] == $srted[0][0]} @srted;
    @{$codels{'d'}} = ($down[-1], $down[0]);

    @srted   = sort {$$a[1] <=> $$b[1]} @bound;
    my @left = sort {$$a[0] <=> $$b[0]} grep {$$_[1] == $srted[0][1]} @srted;
    @{$codels{'l'}} = ($left[-1], $left[0]);

    @srted = sort {$$a[0] <=> $$b[0]} @bound;
    my @up = sort {$$a[1] <=> $$b[1]} grep {$$_[0] == $srted[0][0]} @srted;
    @{$codels{'u'}} = ($up[0], $up[-1]);
    
    if ($opt{d}) { printCorners(); }
}

##\
 # Recursively traces along white codels in a straight line
 # turns at boundary / obstacle
 #
 # param: $ny: y coordinate of current codel
 # param: $nx: x coordinate of current codel
 # param: $i:  trace image codel size
 # param: $im: file name of input image file
 #
 # return: tuple of next codel coordinates
 #/
sub tracewhite {
    my ($ny, $nx, $i, $im) = @_;
    my ($tmpy, $tmpx) = ($ny, $nx);
    my $dir = $dp[$dpval];
    my $out = 0;
    my $bail = 0;
    
    while (!$out) {
        $dir = $dp[$dpval];
        ($ny, $nx) = getnext($dir, $tmpy, $tmpx);
        
        if ($opt{d}) { print DEBUG "current = ($ny,$nx)\n"; }
        
        # TODO - White path infinite termination
        if ($bail) {
            print "\nProgram Terminated: Unescapable White Path\n";
            if ($opt{d}) {
                print DEBUG "Program Terminated: Unescapable White Path\n";
                close (DEBUG);
            }
            if ($opt{t}) { endtrace(basename($im));}
            exit(1);
        }
        
        if (!valid($ny, $nx)) {  # next codel is not valid (boundary / obstacle)
            # change direction
            doswitch(1);
            dopoint(1);
            
            if ($opt{d}) { print DEBUG "shifting direction - obstacle\n"; }
            if ($opt{t}) { tracedot($tmpy, $tmpx, $i); }
        } elsif ($list[$ny][$nx] ~~ "FFFFFF") { # If next codel is white
            if ($opt{t}) { traceline($tmpy, $tmpx, $ny, $nx, $i); }
            if ($opt{d}) { print DEBUG "keep going\n"; }
            
            ($tmpy, $tmpx) = ($ny, $nx);
        } else { # Codel of interest
            $out = 1;
            
            if ($opt{d}) { print DEBUG "found what we want\n"; }
            if ($opt{t}) {
                tracedot($tmpy, $tmpx, $i);
                tracedot($ny, $nx, $i);
                traceline($tmpy, $tmpx, $ny, $nx, $i);
                traceop($tmpy, $tmpx, $ny, $nx, $i, "no-op");
            }
        }
    }
    
    return ($ny, $nx);
}

##\
 # Gets coordinates of next codel given codel coordinates and direction
 #
 # param: $dir: direction
 # param: $y:   y coordinate of codel
 # param: $x:   x coordinate of codel
 #
 # return: tuple of next codel coordinates
 #/
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

##\
 # Given two codels, determine operation to perform on the stack
 #
 # param: $cy: y coordinate of current codel
 # param: $cx: x coordinate of current codel
 # param: $ny: y coordinate of next codel
 # param: $nx: x coordinate of next codel
 # param: $i:  trace image codel size
 #/
sub decideop {
    my ($cy, $cx, $ny, $nx, $i) = @_;
    
    my $color = $list[$cy][$cx];
    my $other = $list[$ny][$nx];
    
    # determine changes
    my ($hue, $light) = colorchange($color, $other);
    
    for ($light) {
        when (0) {
            for ($hue) {
                # nothing
                when (0) {}
                
                # add
                when (1) {
                    if ($opt{d}) { print DEBUG "doadd()\n"; }
                    if ($opt{t}) { traceop($cy, $cx, $ny, $nx, $i, "add"); }
                    doadd();
                }
                
                # divide
                when (2) {
                    if ($opt{d}) { print DEBUG "dodiv()\n"; }
                    if ($opt{t}) { traceop($cy, $cx, $ny, $nx, $i, "div"); }
                    dodiv();
                }
                
                # great
                when (3) {
                    if ($opt{d}) { print DEBUG "dogreat()\n"; }
                    if ($opt{t}) { traceop($cy, $cx, $ny, $nx, $i, "great"); }
                    dogreat();
                }
                
                # duplicate
                when (4) {
                    if ($opt{d}) { print DEBUG "dodup()\n"; }
                    if ($opt{t}) { traceop($cy, $cx, $ny, $nx, $i, "dup"); }
                    dodup();
                }
                
                # In(char)
                when (5) {
                    if ($opt{d}) { print DEBUG "doin(1)\n"; }
                    if ($opt{t}) { traceop($cy, $cx, $ny, $nx, $i, "inC"); }
                    doin(1);
                }
            }
        }
        when (1) {
            for ($hue) {
                # push
                when (0) {
                    my $block = blocksize($cy, $cx, $list[$cy][$cx]);
                    if ($opt{d}) { print DEBUG "dopush($block)\n"; }
                    if ($opt{t}) { traceop($cy, $cx, $ny, $nx, $i, "push($block)"); }
                    dopush($block);
                }
                
                # subtract
                when (1) {
                    if ($opt{d}) { print DEBUG "dosub()\n"; }
                    if ($opt{t}) { traceop($cy, $cx, $ny, $nx, $i, "sub"); }
                    dosub();
                }
                
                # modulus
                when (2) {
                    if ($opt{d}) { print DEBUG "domod()\n"; }
                    if ($opt{t}) { traceop($cy, $cx, $ny, $nx, $i, "mod"); }
                    domod();
                }
                
                # point
                when (3) {
                    if ($opt{d}) { print DEBUG "dopoint()\n"; }
                    if ($opt{t}) { traceop($cy, $cx, $ny, $nx, $i, "point"); }
                    dopoint();
                }
                
                # roll
                when (4) {
                    if ($opt{d}) { print DEBUG "doroll()\n"; }
                    if ($opt{t}) { traceop($cy, $cx, $ny, $nx, $i, "roll"); }
                    doroll();
                }
                
                # Out(int)
                when (5) {
                    if ($opt{d}) { print DEBUG "doout(0)\n"; }
                    if ($opt{t}) { traceop($cy, $cx, $ny, $nx, $i, "outI"); }
                    doout(0);
                }
            }
        }
        when (2) {
            for ($hue) {
                # pop
                when (0) {
                    if ($opt{d}) { print DEBUG "dopop()\n"; }
                    if ($opt{t}) { traceop($cy, $cx, $ny, $nx, $i, "pop"); }
                    dopop();
                }
                
                # multiply
                when (1) {
                    if ($opt{d}) { print DEBUG "domul()\n"; }
                    if ($opt{t}) { traceop($cy, $cx, $ny, $nx, $i, "mul"); }
                    domul();
                }
                
                # not
                when (2) {
                    if ($opt{d}) { print DEBUG "donot()\n"; }
                    if ($opt{t}) { traceop($cy, $cx, $ny, $nx, $i, "not"); }
                    donot();
                }
                
                # switch
                when (3) {
                    if ($opt{d}) { print DEBUG "doswitch()\n"; }
                    if ($opt{t}) { traceop($cy, $cx, $ny, $nx, $i, "switch"); }
                    doswitch();
                }
                
                # In(int)
                when (4) {
                    if ($opt{d}) { print DEBUG "doin(0)\n"; }
                    if ($opt{t}) { traceop($cy, $cx, $ny, $nx, $i, "inI"); }
                    doin(0);
                }
                
                # Out(char)
                when (5) {
                    if ($opt{d}) { print DEBUG "doout(1)\n"; }
                    if ($opt{t}) { traceop($cy, $cx, $ny, $nx, $i, "outC"); }
                    doout(1);
                }
            }
        }
    }
}

##\
 # Given two colors, determines changes between them
 #
 # param: $a: first codel color
 # param: $b: second codel color
 #
 # return: tuple of hue/lightness changes
 #/
sub colorchange {
    my ($a, $b) = @_;
    my ($fhue, $flight) = @{$colors{$a}};
    my ($shue, $slight) = @{$colors{$b}};
    
    my $outh = differ($fhue, $shue, 6);
    my $outl = differ($flight, $slight, 3);
    
    return ($outh, $outl);
}

##\
 # Determines the difference between two numbers (wraps around index)
 # used in getting hue/lightness changes
 #
 # param: $a: first number
 # param: $b: second number
 # param: $index: array size associated (6-hue, 3-lightness)
 #
 # return: difference
 #/
sub differ {
    my ($a, $b, $index) = @_;
    my $out;
    
    if ($b >= $a) {
        $out = $b - $a;
    } else {
        $out = ($b - $a) % $index;
    }
    
    return $out;
}

##\
 # Recursively computes size of block that includes codel at coordinates
 #
 # param: $y:     y coordinate of codel
 # param: $x:     x coordinate of codel
 # param: $color: color of codel
 #
 # return: size of codel block
 #/
sub blocksize {
    no warnings 'recursion';
    
    my ($y, $x, $color) = @_;
    my $temp;
    my $val = 1;
    
    my $pix = sprintf("%d,%d", $y, $x);
    push(@hold, $pix);
    
    # right
    $pix = sprintf("%d,%d", $y, $x + 1);
    if ($x + 1 < @{$list[0]} && !grep {$_ eq ($pix)} @hold) {
        $temp = $list[$y][$x + 1];
        
        if ($temp ~~ $color) { $val += blocksize($y, $x + 1, $color); }
    }
    
    # down
    $pix = sprintf("%d,%d", $y + 1, $x);
    if ($y + 1 < @list && !grep {$_ eq ($pix)} @hold) {
        $temp = $list[$y + 1][$x];
        
        if ($temp ~~ $color) { $val += blocksize($y + 1, $x, $color); }
    }
    
    # left
    $pix = sprintf("%d,%d", $y, $x - 1);
    if ($x - 1 >= 0 && !grep {$_ eq ($pix)} @hold) {
        $temp = $list[$y][$x - 1];
        
        if ($temp ~~ $color) { $val += blocksize($y, $x - 1, $color); }
    }
    
    # up
    $pix = sprintf("%d,%d", $y - 1, $x);
    if ($y - 1 >= 0 && !grep {$_ eq ($pix)} @hold) {
        $temp = $list[$y - 1][$x];
        
        if ($temp ~~ $color) { $val += blocksize($y - 1, $x, $color); }
    }
    
    return $val;
}

sub printStack {
    printf DEBUG "Stack: (%d values): ", scalar @stack;
    print DEBUG "[ ";
        for my $i (reverse @stack) { print DEBUG "$i "; }
    print DEBUG "]\n";
}

sub printCorners {
    print DEBUG "Corners:\n";
    for my $i (keys %codels) {
        print DEBUG " \'$i\'=>( ";
            for my $z (@{$codels{$i}}) { printf DEBUG "(%d,%d) ", @{$z}[0], @{$z}[1]; }
        print DEBUG ")\n";
    }
    print DEBUG "\n";
}

#----------------------------
#-----------Trace------------
#----------------------------

##\
 # Initiates Trace Procedures
 #
 # param: $i: trace image codel size
 #/
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

##\
 # Traces Dot on codel at coordinates on trace image
 #
 # param: $y: y coordinate of codel
 # param: $x: x coordinate of codel
 # param: $i: trace image codel size
 #/
sub tracedot {
    my ($y, $x, $i) = @_;
    
    my $black = $tr->colorResolve(000,000,000);
    $tr->filledArc(($x + 0.5) * $i, ($y + 0.5) * $i, $i / 5, $i / 5, 0, 360, $black);
}

##\
 # Traces Line between two coordinates on trace image
 #
 # param: $ay: y coordinate of first codel
 # param: $ax: x coordinate of first codel
 # param: $by: y coordinate of second codel
 # param: $bx: x coordinate of second codel
 # param: $i:  trace image codel size
 #/
sub traceline {
    my ($ay, $ax, $by, $bx, $i) = @_;
    
    my $black = $tr->colorResolve(000,000,000);
    $tr->line(($ax + 0.5) * $i, ($ay + 0.5) * $i, ($bx + 0.5) * $i, ($by + 0.5) * $i, $black);
}

##\
 # Traces operation on trace image
 #
 # param: $ay: y coordinate of first codel
 # param: $ax: x coordinate of first codel
 # param: $by: y coordinate of second codel
 # param: $bx: x coordinate of second codel
 # param: $i:  trace image codel size
 # param: $op: operation associated with codel comparison
 #/
sub traceop {
    my ($ay, $ax, $by, $bx, $i, $op) = @_;
    my $black = $tr->colorResolve(000,000,000);
    
    my ($adjust, $held) = centerop($ay, $ax, $by, $bx, $op, $i);
    
    if ($ay == $by) { 
        if ($ax > $bx) {
            $tr->string(gdSmallFont, ($bx + $adjust) * $i, ($ay + $held) * $i, $op, $black);
        } else {
            $tr->string(gdSmallFont, ($ax + $adjust) * $i, ($ay + $held) * $i, $op, $black);
        }
    } else {
        if ($ay > $by) {
            $tr->string(gdSmallFont, ($ax + $held) * $i, ($ay - $adjust) * $i, $op, $black);
        } else {
            $tr->string(gdSmallFont, ($ax + $held) * $i, ($by - $adjust) * $i, $op, $black);
        }
    }
}

##\
 # Centers operation in the codel boundaries
 #
 # param: $ay: y coordinate of first codel
 # param: $ax: x coordinate of first codel
 # param: $by: y coordinate of second codel
 # param: $bx: x coordinate of second codel
 # param: $op: operation to be adjusted for
 # param: $i:  trace image codel size
 #
 # return: tuple of adjusts and holds
 #/
sub centerop {
    my ($ay, $ax, $by, $bx, $op, $i) = @_;
    my ($adjust, $held) = (0.7, 0.6);
    
    if ($ay == $by) {
        if ($i >= 100)        { $adjust = 0.8;  }
        if (length $op == 3)  { $adjust = 0.85; }
        if (length $op == 4)  { $adjust = 0.8;  }
        if (length $op == 5)  { $adjust = 0.75; }
        if (length $op == 8)  { $adjust = 0.63; }
        if (length $op == 10) { $adjust = 0.5;  }
    }
    
    if ($ax == $bx) {
        $adjust = 0.1;
        $held = 0.25;
        
        if ($i >= 100)       { $held = 0.3;  }
        if (length $op == 3) { $held = 0.35; }
        if (length $op == 4) { $held = 0.3;  }
        if (length $op == 6) { $held = 0.2;  }
        if (length $op == 7) { $held = 0.2;  }
    }
    
    return ($adjust, $held);
}

##\
 # Ends Trace Procedures
 #
 # param: $image: file name of input image file
 #/
sub endtrace {
    my ($image) = @_;
    
    $image =~ /(\S+)\./;
    $image = $1 . "-trace.png";
    
    open (OUT, '>', $image) or die ("Can't create $image: $!\n");
    binmode (OUT);
    print OUT $tr->png;
    close (OUT);
}

#----------------------------
#-----------Util-------------
#----------------------------

##\
 # Determines closest color to valid colors within a threshold
 #
 # param: $col: color in hex value
 #
 # return: hex value of closest color
 #/
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

##\
 # Converts RGB color to hex
 #
 # param: $r: red color in RGB
 # param: $g: green color in RGB
 # param: $b: blue color in RGB
 #
 # return: string of hex value
 #/
sub rgbtohex {
    my ($r, $g, $b) = @_;
    return sprintf("%02X%02X%02X", $r, $g, $b);
}

##\
 # Converts hex color to RGB
 #
 # param: $s: hex value of color
 #
 # return: triple of RGB values
 #/
sub hextorgb {
    my ($s) = @_;
    my $r = hex(substr($s, 0, 2));
    my $g = hex(substr($s, 2, 2));
    my $b = hex(substr($s, 4));
    
    return ($r, $g, $b);
}


##\
 # Checks if codel at given coordinates is surrounded on all four sides
 # by codels of the same color
 #
 # param: $y:   y coordinate of codel
 # param: $x:   x coordinate of codel
 # param: $col: color of codel
 #
 # return: boolean(0,1)
 #/
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

##\
 # Checks if codel at given coordinates is white
 #
 # param: $y: y coordinate of codel
 # param: $x: x coordinate of codel
 #
 # return: boolean(0,1)
 #/
sub white {
    my ($y, $x) = @_;
    my $out = 0;
    
    if ($list[$y][$x] ~~ "FFFFFF") { $out = 1; }
    
    return $out;
}

##\
 # Checks validity of Codel given coordinates
 # out of bounds / color black
 #
 # param: $y: y coordinate of codel
 # param: $x: x coordinate of codel
 #
 # return: boolean(0,1)
 #/
sub valid {
    my ($y, $x) = @_;
    my $out = 1;
    
    if ($y < 0 || $y >= @list || $x < 0 || $x >= @{$list[0]} || $list[$y][$x] ~~ "000000") {
        $out = 0;
    }
    
    return $out;
}

##\
 # Outputs Image file _image_Big.png
 #
 # param: $image: name of input image file
 # param: $i:     image codel size modifier
 #/
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

#----------------------------
#------Stack Operations------
#----------------------------

##\
 # Stack Helper - push to stack
 #
 # param: $val: element to be pushed to stack
 #/
sub dopush {
    my ($val) = @_;
    push(@stack, $val);
}

##\
 # Stack Helper - pop from stack
 #
 # return: value popped off stack
 #/
sub dopop { return pop(@stack); }


##\
 # Addition of two stack elements
 #/
sub doadd {
    my $one = dopop();
    my $two = dopop();
    
    if (not defined $one || not defined $two) {
        if ($opt{d}) { print DEBUG "Error:doadd: adding with undefined stack elements\n"; }
    } else {
        dopush($one + $two);
    }
}

##\
 # Subtraction of two stack elements
 #/
sub dosub {
    my $one = dopop();
    my $two = dopop();
    
    if (not defined $one || not defined $two) {
        if ($opt{d}) { print DEBUG "Error:dosub: subtracting with undefined stack elements\n"; }
    } else {
        dopush($two - $one);
    }
}

##\
 # Multiplication of two stack elements
 #/
sub domul {
    my $one = dopop();
    my $two = dopop();
    
    if (not defined $one || not defined $two) {
        if ($opt{d}) { print DEBUG "Error:domul: multiplying with undefined stack elements\n"; }
    } else {
        dopush($one * $two);
    }
}

##\
 # Division of two stack elements
 #/
sub dodiv {
    my $one = dopop();
    my $two = dopop();
    
    if (!$one || not defined $two) {
        if ($opt{d}) { print DEBUG "Error:dodiv: dividing with invalid stack elements\n"; }
    } else {
        dopush(int($two / $one));
    }
}

##\
 # Modulus of two stack elements
 #/
sub domod {
    my $one = dopop();
    my $two = dopop();
    
    if (!$one || not defined $two) {
        if ($opt{d}) { print DEBUG "Error:domod: modulus with invalid stack elements\n"; }
    } else {
        dopush($two % $one);
    }
}

##\
 # !stack_element
 #/
sub donot {
    my $one = dopop();
    my $res = 0;
    
    if (defined $one && $one == 0) { $res = 1; }
    dopush($res);
}

##\
 # Compare two stack elements, push bool to stack
 #/
sub dogreat {
    my $one = dopop();
    my $two = dopop();
    my $res = 0;
    
    if (defined $one && defined $two && $two > $one) { $res = 1; }
    dopush($res);
}

##\
 # Shifts dp pointer
 #
 # param: $i: optional shift amount
 #/
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

##\
 # Toggles cc pointer
 #
 # param: $i: optional toggle amount
 #/
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

##\
 # Duplicates top stack element
 #/
sub dodup {
    my $one = dopop();
    
    if (defined $one) {
        dopush($one);
        dopush($one);
    }
}

##\
 # Rolls subset of stack
 #/
sub doroll {
    # number of rolls (negative number roll backwards)
    my $i = dopop();
    
    # length of subset to roll
    my $depth = dopop();
    
    if ($i && $depth) {
        if (@stack - $depth < 0) {
            if ($opt{d}) {
                print DEBUG "Error:doroll: roll not performed\n";
                print DEBUG "depth larger than viable stack\n";
            }
        } else {
            my $start = @stack - $depth;
            my @held = @stack[$start .. @stack - 1];
            
            if ($i < 0) {
                for (0 .. abs($i) - 1) { push(@held, shift (@held)); }
            } else {
                for (0 .. $i - 1) { unshift (@held, pop @held); }
            }
            
            splice (@stack, $start, @held, @held);
        }
    } else {
        if ($opt{d}) {
            print DEBUG "Error:doroll: roll not performed\n";
            print DEBUG "0 iterations\n" if (!$i);
            print DEBUG "0 depth\n" if (!$depth);
        }
    }
}

##\
 # Inputs either char or integer into stack
 #
 # param: $mode: determines type of input
 #/
sub doin {
    my ($mode) = @_;
    my $val;
    
    if ($buffer) {
        if ($opt{d}) { print DEBUG "Buffer Input Used\n"; }
        
        if ($mode) {
            $val = substr($buffer, 0, 1);
            dopush(ord $val);
            
            $buffer = substr($buffer, 1);
        } else {
            $buffer =~ /(\d+).*/;
            $val = (defined $1) ? $1 : "";
            
            if ($val ~~ "") {
                if ($opt{d}) {
                    print DEBUG "Error:doin: input not number\n";
                    print DEBUG "Found return character: new input\n";
                }
                
                $buffer = "";
                doin($mode);
            } else {
                dopush(int $val);
                $buffer = substr($buffer, length $val);
            }
        }
    } else {
        print "?";
        $val = <>;
        
        if (not defined $val) {
            if ($opt{d}) { print DEBUG "Error:doin: no input found\n"; }
        } else {
            $buffer = $val;
            
            if ($mode) {
                $val = substr($buffer, 0, 1);
                dopush(ord $val);
                
                $buffer = substr($buffer, 1);
            } else {
                $buffer =~ /(\d+).*/;
                $val = (defined $1) ? $1 : "";
                
                if ($val ~~ "") {
                    if ($opt{d}) { print DEBUG "Error:doin: input not number\n"; }
                } else {
                    dopush(int $val);
                    $buffer = substr($buffer, length $val);
                }
            }
        }
    }
}

##\
 # Outputs either char or integer from stack
 #
 # param: $mode: determines type of output
 #/
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