<div>
    <p><a href="https://github.com/philiprbrenan/SiliconChipWiring"><img src="https://github.com/philiprbrenan/SiliconChipWiring/workflows/Test/badge.svg"></a>
</div>

# Name

Silicon::Chip::Wiring - Wire up a [silicon](https://en.wikipedia.org/wiki/Silicon) [chip](https://en.wikipedia.org/wiki/Integrated_circuit) to combine [logic gates](https://en.wikipedia.org/wiki/Logic_gate) to transform software into hardware.

file:///home/phil/perl/cpan/SiliconChipWiring/lib/Silicon/Chip/svg/xy2\_1.svg

# Synopsis

## Wire up a silicon chip

<div>
    <p><img src="https://raw.githubusercontent.com/philiprbrenan/SiliconChipWiring/main/lib/Silicon/Chip/svg/xy2_1.svg">
</div>

## Assumptions

The gates are on the bottom layer if the chip.  Above the gates layer there as
many wiring levels as are needed to connect the gates. Vertical vias run from
the pins of the gates to each layer, so each vertical via can connect to an
input pin or an output pin of a gate.  On each level some of the vias (hence
gate pins) are connected together by L shaped strips of metal conductor running
along X and Y. The Y strips can cross over the X strips.  Each gate input pin
is connect to no more than one gate output pin.  Each gate output pin is
connected to no more than one gate input pin.  [Silicon::Chip](https://metacpan.org/pod/Silicon%3A%3AChip) automatically
inserts fan outs to enforce this rule. The fan outs look like sea shells on the
gate layout diagrams.

# Description

Wire up a [silicon](https://en.wikipedia.org/wiki/Silicon) [chip](https://en.wikipedia.org/wiki/Integrated_circuit) to combine [logic gates](https://en.wikipedia.org/wiki/Logic_gate) to transform software into hardware.

Version 20240331.

The following sections describe the methods in each functional area of this
module.  For an alphabetic listing of all methods by name see [Index](#index).

# Construct

Create a Silicon chip wiring diagram on one or more levels as necessary to make the connections requested.

## new (%options)

New wiring diagram.

       Parameter  Description
    1  %options   Options

**Example:**

    if (1)

     {my      $d = new(width=>4, height=>3, log=>1);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

      my $a = $d->wire(0, 1, 2, 1, n=>'a');
              $d->layout;

      is_deeply(printPath($a->p), <<END);
    .........
    .........
    000000001
    1.......1
    S.......F
    END
     }

    if (1)

     {my        $d = new(width=>5, height=>5, log=>0);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

      my $a =   $d->wire(0, 1, 2, 1, n=>'a');
      my $b =   $d->wire(1, 0, 1, 2, n=>'b');
      my $c =   $d->wire(2, 0, 2, 2, n=>'c');
      my $e =   $d->wire(0, 2, 1, 1, n=>'e');
      my $f =   $d->wire(0, 3, 4, 0, n=>'f');
      my $F =   $d->wire(1, 3, 3, 0, n=>'F');

                $d->layout;
      is_deeply($d->levels, 1);

      my $g =   $d->wire(0, 0, 3, 0, n=>'g');

                $d->layout;
      is_deeply($d->levels, 2);
      is_deeply($d->totalLength, 119);
      is_deeply($d->levels, 2);

      my $expected = <<END;
    Length: 119
       x,   y      X,   Y   L  Name    Path
       0,   0      3,   0   2  g       0,0,1  0,1,1  0,2,0  1,2,0  2,2,0  3,2,0  4,2,0  5,2,0  6,2,0  7,2,0  8,2,0  9,2,0  10,2,0  11,2,0  12,2,1  12,1,1  12,0
       0,   1      2,   1   1  a       0,4,1  0,3,1  0,2,0  1,2,0  2,2,0  3,2,0  4,2,0  5,2,0  6,2,0  7,2,0  8,2,1  8,3,1  8,4
       0,   2      1,   1   1  e       0,8,1  0,7,1  0,6,0  1,6,0  2,6,0  3,6,0  4,6,1  4,5,1  4,4
       0,   3      4,   0   1  f       0,12,1  0,11,1  0,10,0  1,10,0  2,10,0  3,10,0  4,10,0  5,10,0  6,10,0  7,10,0  8,10,0  9,10,0  10,10,0  11,10,0  12,10,0  13,10,0  14,10,1  14,9,1  14,8,1  14,7,1  14,6,1  14,5,1  14,4,1  14,3,1  14,2,1  14,1,1  14,0,0  15,0,0  16,0
       1,   0      1,   2   1  b       4,0,0  3,0,0  2,0,1  2,1,1  2,2,1  2,3,1  2,4,1  2,5,1  2,6,1  2,7,1  2,8,0  3,8,0  4,8
       1,   3      3,   0   1  F       4,12,1  4,13,1  4,14,0  5,14,0  6,14,0  7,14,0  8,14,0  9,14,0  10,14,1  10,13,1  10,12,1  10,11,1  10,10,1  10,9,1  10,8,1  10,7,1  10,6,1  10,5,1  10,4,1  10,3,1  10,2,1  10,1,1  10,0,0  11,0,0  12,0
       2,   0      2,   2   1  c       8,0,0  7,0,0  6,0,1  6,1,1  6,2,1  6,3,1  6,4,1  6,5,1  6,6,1  6,7,1  6,8,0  7,8,0  8,8
    END

      $d->layout;     is_deeply($d->printInOrder, $expected);

      is_deeply(printPath($a->p), <<END);
    .........
    .........
    000000001
    1.......1
    S.......F
    END

      is_deeply(printPath($b->p), <<END);
    ..10S
    ..1..
    ..1..
    ..1..
    ..1..
    ..1..
    ..1..
    ..1..
    ..00F
    END

      is_deeply(printPath($c->p), <<END);
    ......10S
    ......1..
    ......1..
    ......1..
    ......1..
    ......1..
    ......1..
    ......1..
    ......00F
    END

      is_deeply(printPath($e->p), <<END);
    .....
    .....
    .....
    .....
    ....F
    ....1
    00001
    1....
    S....
    END

      is_deeply(printPath($f->p), <<END);
    ..............00F
    ..............1..
    ..............1..
    ..............1..
    ..............1..
    ..............1..
    ..............1..
    ..............1..
    ..............1..
    ..............1..
    000000000000001..
    1................
    S................
    END

      is_deeply(printPath($F->p), <<END);
    ..........00F
    ..........1..
    ..........1..
    ..........1..
    ..........1..
    ..........1..
    ..........1..
    ..........1..
    ..........1..
    ..........1..
    ..........1..
    ..........1..
    ....S.....1..
    ....1.....1..
    ....0000001..
    END


      is_deeply(printPath($g->p), <<END);
    S...........F
    1...........1
    0000000000001
    END
      $d->layout;
      $d->svg (svg=>q(xy2), pngs=>2);
      $d->gds2(svg=>q/xy2/);
     }

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChipWiring/lib/Silicon/Chip/png/xy2.png">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChipWiring/lib/Silicon/Chip/png/xy2_1.png">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChipWiring/lib/Silicon/Chip/png/xy2_2.png">
</div>

## wire($diagram, $x, $y, $X, $Y, %options)

New wire on a wiring diagram.

       Parameter  Description
    1  $diagram   Diagram
    2  $x         Start x
    3  $y         Start y
    4  $X         End x
    5  $Y         End y
    6  %options   Options

**Example:**

    if (1)
     {my      $d = new(width=>4, height=>3, log=>1);

      my $a = $d->wire(0, 1, 2, 1, n=>'a');  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

              $d->layout;

      is_deeply(printPath($a->p), <<END);
    .........
    .........
    000000001
    1.......1
    S.......F
    END
     }

    if (1)
     {my        $d = new(width=>5, height=>5, log=>0);

      my $a =   $d->wire(0, 1, 2, 1, n=>'a');  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲


      my $b =   $d->wire(1, 0, 1, 2, n=>'b');  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲


      my $c =   $d->wire(2, 0, 2, 2, n=>'c');  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲


      my $e =   $d->wire(0, 2, 1, 1, n=>'e');  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲


      my $f =   $d->wire(0, 3, 4, 0, n=>'f');  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲


      my $F =   $d->wire(1, 3, 3, 0, n=>'F');  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲


                $d->layout;
      is_deeply($d->levels, 1);


      my $g =   $d->wire(0, 0, 3, 0, n=>'g');  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲


                $d->layout;
      is_deeply($d->levels, 2);
      is_deeply($d->totalLength, 119);
      is_deeply($d->levels, 2);

      my $expected = <<END;
    Length: 119
       x,   y      X,   Y   L  Name    Path
       0,   0      3,   0   2  g       0,0,1  0,1,1  0,2,0  1,2,0  2,2,0  3,2,0  4,2,0  5,2,0  6,2,0  7,2,0  8,2,0  9,2,0  10,2,0  11,2,0  12,2,1  12,1,1  12,0
       0,   1      2,   1   1  a       0,4,1  0,3,1  0,2,0  1,2,0  2,2,0  3,2,0  4,2,0  5,2,0  6,2,0  7,2,0  8,2,1  8,3,1  8,4
       0,   2      1,   1   1  e       0,8,1  0,7,1  0,6,0  1,6,0  2,6,0  3,6,0  4,6,1  4,5,1  4,4
       0,   3      4,   0   1  f       0,12,1  0,11,1  0,10,0  1,10,0  2,10,0  3,10,0  4,10,0  5,10,0  6,10,0  7,10,0  8,10,0  9,10,0  10,10,0  11,10,0  12,10,0  13,10,0  14,10,1  14,9,1  14,8,1  14,7,1  14,6,1  14,5,1  14,4,1  14,3,1  14,2,1  14,1,1  14,0,0  15,0,0  16,0
       1,   0      1,   2   1  b       4,0,0  3,0,0  2,0,1  2,1,1  2,2,1  2,3,1  2,4,1  2,5,1  2,6,1  2,7,1  2,8,0  3,8,0  4,8
       1,   3      3,   0   1  F       4,12,1  4,13,1  4,14,0  5,14,0  6,14,0  7,14,0  8,14,0  9,14,0  10,14,1  10,13,1  10,12,1  10,11,1  10,10,1  10,9,1  10,8,1  10,7,1  10,6,1  10,5,1  10,4,1  10,3,1  10,2,1  10,1,1  10,0,0  11,0,0  12,0
       2,   0      2,   2   1  c       8,0,0  7,0,0  6,0,1  6,1,1  6,2,1  6,3,1  6,4,1  6,5,1  6,6,1  6,7,1  6,8,0  7,8,0  8,8
    END

      $d->layout;     is_deeply($d->printInOrder, $expected);

      is_deeply(printPath($a->p), <<END);
    .........
    .........
    000000001
    1.......1
    S.......F
    END

      is_deeply(printPath($b->p), <<END);
    ..10S
    ..1..
    ..1..
    ..1..
    ..1..
    ..1..
    ..1..
    ..1..
    ..00F
    END

      is_deeply(printPath($c->p), <<END);
    ......10S
    ......1..
    ......1..
    ......1..
    ......1..
    ......1..
    ......1..
    ......1..
    ......00F
    END

      is_deeply(printPath($e->p), <<END);
    .....
    .....
    .....
    .....
    ....F
    ....1
    00001
    1....
    S....
    END

      is_deeply(printPath($f->p), <<END);
    ..............00F
    ..............1..
    ..............1..
    ..............1..
    ..............1..
    ..............1..
    ..............1..
    ..............1..
    ..............1..
    ..............1..
    000000000000001..
    1................
    S................
    END

      is_deeply(printPath($F->p), <<END);
    ..........00F
    ..........1..
    ..........1..
    ..........1..
    ..........1..
    ..........1..
    ..........1..
    ..........1..
    ..........1..
    ..........1..
    ..........1..
    ..........1..
    ....S.....1..
    ....1.....1..
    ....0000001..
    END


      is_deeply(printPath($g->p), <<END);
    S...........F
    1...........1
    0000000000001
    END
      $d->layout;
      $d->svg (svg=>q(xy2), pngs=>2);
      $d->gds2(svg=>q/xy2/);
     }

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChipWiring/lib/Silicon/Chip/png/xy2.png">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChipWiring/lib/Silicon/Chip/png/xy2_1.png">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChipWiring/lib/Silicon/Chip/png/xy2_2.png">
</div>

## layout  ($diagram, %options)

Layout the wires using Java

       Parameter  Description
    1  $diagram   Diagram
    2  %options   Options

## numberOfWires   ($D, %options)

Number of wires in the diagram

       Parameter  Description
    1  $D         Diagram
    2  %options   Options

**Example:**

    if (1)
     {my      $d = new(width=>3, height=>2);
      my $w = $d->wire(1, 1, 2, 1, n=>'a');
              $d->layout;

      is_deeply($d->numberOfWires, 1);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

      is_deeply(printPath($w->p), <<END);
    .........
    .........
    .........
    .........
    ....S000F
    END
      $d->gds2(svg=>q(x1));
     }

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChipWiring/lib/Silicon/Chip/svg/x1.svg">
</div>

## length  ($D, $w)

Length of a wire in a diagram

       Parameter  Description
    1  $D         Diagram
    2  $w         Wire

**Example:**

    if (1)
     {my      $d = new(width=>2, height=>3);
      my $w = $d->wire(1, 1, 1, 2, n=>'b');
              $d->layout;

      is_deeply($d->length($w), 5);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

      is_deeply(printPath($w->p), <<END);
    .....
    .....
    .....
    .....
    ....S
    ....1
    ....1
    ....1
    ....F
    END
      $d->svg (svg=>q(y1));
      $d->gds2(svg=>q(y1));
     }

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChipWiring/lib/Silicon/Chip/svg/y1.svg">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChipWiring/lib/Silicon/Chip/svg/y1_1.svg">
</div>

## totalLength ($d)

Total length of wires

       Parameter  Description
    1  $d         Diagram

**Example:**

    if (1)
     {my      $d = new(width=>4, height=>3, log=>1);
      my $a = $d->wire(0, 1, 2, 1, n=>'a');
              $d->layout;

      is_deeply(printPath($a->p), <<END);
    .........
    .........
    000000001
    1.......1
    S.......F
    END
     }

    if (1)
     {my        $d = new(width=>5, height=>5, log=>0);
      my $a =   $d->wire(0, 1, 2, 1, n=>'a');
      my $b =   $d->wire(1, 0, 1, 2, n=>'b');
      my $c =   $d->wire(2, 0, 2, 2, n=>'c');
      my $e =   $d->wire(0, 2, 1, 1, n=>'e');
      my $f =   $d->wire(0, 3, 4, 0, n=>'f');
      my $F =   $d->wire(1, 3, 3, 0, n=>'F');

                $d->layout;
      is_deeply($d->levels, 1);

      my $g =   $d->wire(0, 0, 3, 0, n=>'g');

                $d->layout;
      is_deeply($d->levels, 2);

      is_deeply($d->totalLength, 119);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

      is_deeply($d->levels, 2);

      my $expected = <<END;
    Length: 119
       x,   y      X,   Y   L  Name    Path
       0,   0      3,   0   2  g       0,0,1  0,1,1  0,2,0  1,2,0  2,2,0  3,2,0  4,2,0  5,2,0  6,2,0  7,2,0  8,2,0  9,2,0  10,2,0  11,2,0  12,2,1  12,1,1  12,0
       0,   1      2,   1   1  a       0,4,1  0,3,1  0,2,0  1,2,0  2,2,0  3,2,0  4,2,0  5,2,0  6,2,0  7,2,0  8,2,1  8,3,1  8,4
       0,   2      1,   1   1  e       0,8,1  0,7,1  0,6,0  1,6,0  2,6,0  3,6,0  4,6,1  4,5,1  4,4
       0,   3      4,   0   1  f       0,12,1  0,11,1  0,10,0  1,10,0  2,10,0  3,10,0  4,10,0  5,10,0  6,10,0  7,10,0  8,10,0  9,10,0  10,10,0  11,10,0  12,10,0  13,10,0  14,10,1  14,9,1  14,8,1  14,7,1  14,6,1  14,5,1  14,4,1  14,3,1  14,2,1  14,1,1  14,0,0  15,0,0  16,0
       1,   0      1,   2   1  b       4,0,0  3,0,0  2,0,1  2,1,1  2,2,1  2,3,1  2,4,1  2,5,1  2,6,1  2,7,1  2,8,0  3,8,0  4,8
       1,   3      3,   0   1  F       4,12,1  4,13,1  4,14,0  5,14,0  6,14,0  7,14,0  8,14,0  9,14,0  10,14,1  10,13,1  10,12,1  10,11,1  10,10,1  10,9,1  10,8,1  10,7,1  10,6,1  10,5,1  10,4,1  10,3,1  10,2,1  10,1,1  10,0,0  11,0,0  12,0
       2,   0      2,   2   1  c       8,0,0  7,0,0  6,0,1  6,1,1  6,2,1  6,3,1  6,4,1  6,5,1  6,6,1  6,7,1  6,8,0  7,8,0  8,8
    END

      $d->layout;     is_deeply($d->printInOrder, $expected);

      is_deeply(printPath($a->p), <<END);
    .........
    .........
    000000001
    1.......1
    S.......F
    END

      is_deeply(printPath($b->p), <<END);
    ..10S
    ..1..
    ..1..
    ..1..
    ..1..
    ..1..
    ..1..
    ..1..
    ..00F
    END

      is_deeply(printPath($c->p), <<END);
    ......10S
    ......1..
    ......1..
    ......1..
    ......1..
    ......1..
    ......1..
    ......1..
    ......00F
    END

      is_deeply(printPath($e->p), <<END);
    .....
    .....
    .....
    .....
    ....F
    ....1
    00001
    1....
    S....
    END

      is_deeply(printPath($f->p), <<END);
    ..............00F
    ..............1..
    ..............1..
    ..............1..
    ..............1..
    ..............1..
    ..............1..
    ..............1..
    ..............1..
    ..............1..
    000000000000001..
    1................
    S................
    END

      is_deeply(printPath($F->p), <<END);
    ..........00F
    ..........1..
    ..........1..
    ..........1..
    ..........1..
    ..........1..
    ..........1..
    ..........1..
    ..........1..
    ..........1..
    ..........1..
    ..........1..
    ....S.....1..
    ....1.....1..
    ....0000001..
    END


      is_deeply(printPath($g->p), <<END);
    S...........F
    1...........1
    0000000000001
    END
      $d->layout;
      $d->svg (svg=>q(xy2), pngs=>2);
      $d->gds2(svg=>q/xy2/);
     }

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChipWiring/lib/Silicon/Chip/png/xy2.png">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChipWiring/lib/Silicon/Chip/png/xy2_1.png">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChipWiring/lib/Silicon/Chip/png/xy2_2.png">
</div>

# Shortest Path

Find the shortest path using compiled code

# Visualize

Visualize a Silicon chip wiring diagrams

## printCode   ($d, %options)

Print code to create a diagram

       Parameter  Description
    1  $d         Drawing
    2  %options   Options

**Example:**

    if (1)
     {my      $d = new(width=>3, height=>3);
      my $a = $d->wire(1, 1, 2, 1, n=>'a');
      my $b = $d->wire(1, 2, 2, 2, n=>'b');
              $d->layout;
      is_deeply($d->print, <<END);
    Length: 10
       x,   y      X,   Y   L  Name    Path
       1,   1      2,   1   1  a       4,4,0  5,4,0  6,4,0  7,4,0  8,4
       1,   2      2,   2   1  b       4,8,0  5,8,0  6,8,0  7,8,0  8,8
    END
      is_deeply($d->printWire($a), "   1,   1      2,   1   1  a       4,4,0  5,4,0  6,4,0  7,4,0  8,4");

      is_deeply($d->printCode, <<END);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

    Silicon::Chip::Wiring::new(width=>3, height=>3);
    \$d->wire(   1,    1,    2,    1);
    \$d->wire(   1,    2,    2,    2);
    END
      is_deeply($d->printInOrder, <<END);
    Length: 10
       x,   y      X,   Y   L  Name    Path
       1,   1      2,   1   1  a       4,4,0  5,4,0  6,4,0  7,4,0  8,4
       1,   2      2,   2   1  b       4,8,0  5,8,0  6,8,0  7,8,0  8,8
    END
     }

## print   ($d, %options)

Print a diagram

       Parameter  Description
    1  $d         Drawing
    2  %options   Options

**Example:**

    if (1)
     {my      $d = new(width=>3, height=>3);
      my $a = $d->wire(1, 1, 2, 1, n=>'a');
      my $b = $d->wire(1, 2, 2, 2, n=>'b');
              $d->layout;

      is_deeply($d->print, <<END);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

    Length: 10
       x,   y      X,   Y   L  Name    Path
       1,   1      2,   1   1  a       4,4,0  5,4,0  6,4,0  7,4,0  8,4
       1,   2      2,   2   1  b       4,8,0  5,8,0  6,8,0  7,8,0  8,8
    END
      is_deeply($d->printWire($a), "   1,   1      2,   1   1  a       4,4,0  5,4,0  6,4,0  7,4,0  8,4");
      is_deeply($d->printCode, <<END);
    Silicon::Chip::Wiring::new(width=>3, height=>3);
    \$d->wire(   1,    1,    2,    1);
    \$d->wire(   1,    2,    2,    2);
    END
      is_deeply($d->printInOrder, <<END);
    Length: 10
       x,   y      X,   Y   L  Name    Path
       1,   1      2,   1   1  a       4,4,0  5,4,0  6,4,0  7,4,0  8,4
       1,   2      2,   2   1  b       4,8,0  5,8,0  6,8,0  7,8,0  8,8
    END
     }

## printInOrder($d, %options)

Print a diagram

       Parameter  Description
    1  $d         Drawing
    2  %options   Options

**Example:**

    if (1)
     {my      $d = new(width=>3, height=>3);
      my $a = $d->wire(1, 1, 2, 1, n=>'a');
      my $b = $d->wire(1, 2, 2, 2, n=>'b');
              $d->layout;
      is_deeply($d->print, <<END);
    Length: 10
       x,   y      X,   Y   L  Name    Path
       1,   1      2,   1   1  a       4,4,0  5,4,0  6,4,0  7,4,0  8,4
       1,   2      2,   2   1  b       4,8,0  5,8,0  6,8,0  7,8,0  8,8
    END
      is_deeply($d->printWire($a), "   1,   1      2,   1   1  a       4,4,0  5,4,0  6,4,0  7,4,0  8,4");
      is_deeply($d->printCode, <<END);
    Silicon::Chip::Wiring::new(width=>3, height=>3);
    \$d->wire(   1,    1,    2,    1);
    \$d->wire(   1,    2,    2,    2);
    END

      is_deeply($d->printInOrder, <<END);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

    Length: 10
       x,   y      X,   Y   L  Name    Path
       1,   1      2,   1   1  a       4,4,0  5,4,0  6,4,0  7,4,0  8,4
       1,   2      2,   2   1  b       4,8,0  5,8,0  6,8,0  7,8,0  8,8
    END
     }

## printWire   ($D, $W)

Print a wire to a string

       Parameter  Description
    1  $D         Drawing
    2  $W         Wire

**Example:**

    if (1)
     {my      $d = new(width=>3, height=>3);
      my $a = $d->wire(1, 1, 2, 1, n=>'a');
      my $b = $d->wire(1, 2, 2, 2, n=>'b');
              $d->layout;
      is_deeply($d->print, <<END);
    Length: 10
       x,   y      X,   Y   L  Name    Path
       1,   1      2,   1   1  a       4,4,0  5,4,0  6,4,0  7,4,0  8,4
       1,   2      2,   2   1  b       4,8,0  5,8,0  6,8,0  7,8,0  8,8
    END

      is_deeply($d->printWire($a), "   1,   1      2,   1   1  a       4,4,0  5,4,0  6,4,0  7,4,0  8,4");  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

      is_deeply($d->printCode, <<END);
    Silicon::Chip::Wiring::new(width=>3, height=>3);
    \$d->wire(   1,    1,    2,    1);
    \$d->wire(   1,    2,    2,    2);
    END
      is_deeply($d->printInOrder, <<END);
    Length: 10
       x,   y      X,   Y   L  Name    Path
       1,   1      2,   1   1  a       4,4,0  5,4,0  6,4,0  7,4,0  8,4
       1,   2      2,   2   1  b       4,8,0  5,8,0  6,8,0  7,8,0  8,8
    END
     }

## printPath   ($P)

Print a path as a two dimensional character image

       Parameter  Description
    1  $P         Path

**Example:**

    if (1)
     {my      $d = new(width=>3, height=>3);
      my $a = $d->wire(1, 1, 2, 2, n=>'a');
              $d->layout;

      is_deeply(printPath($a->p), <<END);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

    .........
    .........
    .........
    .........
    ....S01..
    ......1..
    ......1..
    ......1..
    ......00F
    END
      $d->gds2(svg=>q(xy1));
      $d->svg (svg=>q(xy1));
     }

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChipWiring/lib/Silicon/Chip/svg/xy1.svg">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChipWiring/lib/Silicon/Chip/svg/xy1_1.svg">
</div>

## svg ($D, %options)

Draw the bus lines by level.

       Parameter  Description
    1  $D         Wiring diagram
    2  %options   Options

**Example:**

    if (1)
     {my      $d = new(width=>2, height=>3);
      my $w = $d->wire(1, 1, 1, 2, n=>'b');
              $d->layout;
      is_deeply($d->length($w), 5);
      is_deeply(printPath($w->p), <<END);
    .....
    .....
    .....
    .....
    ....S
    ....1
    ....1
    ....1
    ....F
    END

      $d->svg (svg=>q(y1));  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲


      $d->gds2(svg=>q(y1));  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

     }

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChipWiring/lib/Silicon/Chip/svg/y1.svg">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChipWiring/lib/Silicon/Chip/svg/y1_1.svg">
</div>

## gds2($diagram, %options)

Draw the wires using GDS2

       Parameter  Description
    1  $diagram   Wiring diagram
    2  %options   Output file

**Example:**

    if (1)
     {my      $d = new(width=>2, height=>3);
      my $w = $d->wire(1, 1, 1, 2, n=>'b');
              $d->layout;
      is_deeply($d->length($w), 5);
      is_deeply(printPath($w->p), <<END);
    .....
    .....
    .....
    .....
    ....S
    ....1
    ....1
    ....1
    ....F
    END
      $d->svg (svg=>q(y1));

      $d->gds2(svg=>q(y1));  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

     }

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChipWiring/lib/Silicon/Chip/svg/y1.svg">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChipWiring/lib/Silicon/Chip/svg/y1_1.svg">
</div>

# Hash Definitions

## Silicon::Chip::Wiring Definition

Wire

### Output fields

#### X

End   x position of wire

#### Y

End   y position of wire

#### height

Height of chip

#### l

Level on which wire is drawn

#### levelX

{level}{x}{y} - available cells in X  - used cells are deleted. Normally if present the cell, if present has a positive value.  If it has a negative it is a temporary addition for the purpose of connecting the end points of the wires to the vertical vias.

#### levelY

{level}{x}{y} - available cells in Y

#### levels

Levels in use

#### log

Log activity if true

#### n

Optional name

#### options

Creation options

#### p

Path from start to finish

#### width

Width of chip

#### wires

Wires on diagram

#### x

Start x position of wire

#### y

Start y position of wire

# Private Methods

## resetLevels ($diagram, %options)

Reset all the levels so we can layout again

       Parameter  Description
    1  $diagram   Diagram
    2  %options   Options

## java()

Using Java as it is faster than Perl to layout the connections

## printHash   ($x)

Print a two dimensional hash

       Parameter  Description
    1  $x         Two dimensional hash

## printCells  ($diagram, $level)

Print the cells and sub cells in a diagram

       Parameter  Description
    1  $diagram   Diagram
    2  $level

## svgLevel($D, $level, %options)

Draw the bus lines by level.

       Parameter  Description
    1  $D         Wiring diagram
    2  $level     Level
    3  %options   Options

# Index

1 [gds2](#gds2) - Draw the wires using GDS2

2 [java](#java) - Using Java as it is faster than Perl to layout the connections

3 [layout](#layout) - Layout the wires using Java

4 [length](#length) - Length of a wire in a diagram

5 [new](#new) - New wiring diagram.

6 [numberOfWires](#numberofwires) - Number of wires in the diagram

7 [print](#print) - Print a diagram

8 [printCells](#printcells) - Print the cells and sub cells in a diagram

9 [printCode](#printcode) - Print code to create a diagram

10 [printHash](#printhash) - Print a two dimensional hash

11 [printInOrder](#printinorder) - Print a diagram

12 [printPath](#printpath) - Print a path as a two dimensional character image

13 [printWire](#printwire) - Print a wire to a string

14 [resetLevels](#resetlevels) - Reset all the levels so we can layout again

15 [svg](#svg) - Draw the bus lines by level.

16 [svgLevel](#svglevel) - Draw the bus lines by level.

17 [totalLength](#totallength) - Total length of wires

18 [wire](#wire) - New wire on a wiring diagram.

# Installation

This module is written in 100% Pure Perl and, thus, it is easy to read,
comprehend, use, modify and install via **cpan**:

    sudo cpan install Silicon::Chip::Wiring

# Author

[philiprbrenan@gmail.com](mailto:philiprbrenan@gmail.com)

[http://prb.appaapps.com](http://prb.appaapps.com)

# Copyright

Copyright (c) 2016-2023 Philip R Brenan.

This module is free software. It may be used, redistributed and/or modified
under the same terms as Perl itself.
