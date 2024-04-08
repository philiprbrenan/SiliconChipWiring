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

     {my      $d = new(width=>4, height=>3);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

      my $a = $d->wire(x=>0, y=>1, X=>2, Y=>1, n=>'a');
      my $b = $d->wire(x=>1, y=>0, X=>1, Y=>2, n=>'b');
      my $c = $d->wire(x=>2, y=>0, X=>2, Y=>2, n=>'c');
      my $e = $d->wire(x=>0, y=>2, X=>1, Y=>1, n=>'e');
      my $f = $d->wire(x=>0, y=>3, X=>4, Y=>0, n=>'f');
      my $F = $d->wire(x=>1, y=>3, X=>3, Y=>0, n=>'F');

      is_deeply($d->levels, 1);
      my $g = $d->wire(x=>0, y=>0, X=>3, Y=>0, n=>'g');
      is_deeply($d->levels, 2);
      is_deeply($d->totalLength, 119);
      is_deeply($d->levels, 2);


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
    ....S01...1..
    ......1...1..
    ......00001..
    END


      is_deeply(printPath($g->p), <<END);
    S...........F
    1...........1
    0000000000001
    END
      $d->svg (svg=>q(xy2), pngs=>2);
      $d->gds2(svg=>q/xy2/);
     }

<div>
    <img src="https://raw.githubusercontent.com/philiprbrenan/SiliconChipWiring/main/lib/Silicon/Chip/png/xy2.png">
</div>

<div>
    <img src="https://raw.githubusercontent.com/philiprbrenan/SiliconChipWiring/main/lib/Silicon/Chip/png/xy2_1.png">
</div>

<div>
    <img src="https://raw.githubusercontent.com/philiprbrenan/SiliconChipWiring/main/lib/Silicon/Chip/png/xy2_2.png">
</div>

## wire($diagram, %options)

New wire on a wiring diagram.

       Parameter  Description
    1  $diagram   Diagram
    2  %options   Options

**Example:**

    if (1)
     {my      $d = new(width=>4, height=>3);

      my $a = $d->wire(x=>0, y=>1, X=>2, Y=>1, n=>'a');  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲


      my $b = $d->wire(x=>1, y=>0, X=>1, Y=>2, n=>'b');  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲


      my $c = $d->wire(x=>2, y=>0, X=>2, Y=>2, n=>'c');  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲


      my $e = $d->wire(x=>0, y=>2, X=>1, Y=>1, n=>'e');  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲


      my $f = $d->wire(x=>0, y=>3, X=>4, Y=>0, n=>'f');  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲


      my $F = $d->wire(x=>1, y=>3, X=>3, Y=>0, n=>'F');  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲


      is_deeply($d->levels, 1);

      my $g = $d->wire(x=>0, y=>0, X=>3, Y=>0, n=>'g');  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

      is_deeply($d->levels, 2);
      is_deeply($d->totalLength, 119);
      is_deeply($d->levels, 2);


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
    ....S01...1..
    ......1...1..
    ......00001..
    END


      is_deeply(printPath($g->p), <<END);
    S...........F
    1...........1
    0000000000001
    END
      $d->svg (svg=>q(xy2), pngs=>2);
      $d->gds2(svg=>q/xy2/);
     }

<div>
    <img src="https://raw.githubusercontent.com/philiprbrenan/SiliconChipWiring/main/lib/Silicon/Chip/png/xy2.png">
</div>

<div>
    <img src="https://raw.githubusercontent.com/philiprbrenan/SiliconChipWiring/main/lib/Silicon/Chip/png/xy2_1.png">
</div>

<div>
    <img src="https://raw.githubusercontent.com/philiprbrenan/SiliconChipWiring/main/lib/Silicon/Chip/png/xy2_2.png">
</div>

## numberOfWires   ($D, %options)

Number of wires in the diagram

       Parameter  Description
    1  $D         Diagram
    2  %options   Options

**Example:**

    if (1)
     {my      $d = new(width=>3, height=>2);
      my $w = $d->wire(x=>1, y=>1, X=>2, Y=>1, n=>'a');

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
    <img src="https://raw.githubusercontent.com/philiprbrenan/SiliconChipWiring/main/lib/Silicon/Chip/svg/x1.svg">
</div>

## length  ($D, $w)

Length of a wire in a diagram

       Parameter  Description
    1  $D         Diagram
    2  $w         Wire

**Example:**

    if (1)
     {my      $d = new(width=>1, height=>2);
      my $w = $d->wire(x=>1, y=>1, X=>1, Y=>2, n=>'b');

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
    <img src="https://raw.githubusercontent.com/philiprbrenan/SiliconChipWiring/main/lib/Silicon/Chip/svg/y1.svg">
</div>

<div>
    <img src="https://raw.githubusercontent.com/philiprbrenan/SiliconChipWiring/main/lib/Silicon/Chip/svg/y1_1.svg">
</div>

## totalLength ($d)

Total length of wires

       Parameter  Description
    1  $d         Diagram

**Example:**

    if (1)
     {my      $d = new(width=>4, height=>3);
      my $a = $d->wire(x=>0, y=>1, X=>2, Y=>1, n=>'a');
      my $b = $d->wire(x=>1, y=>0, X=>1, Y=>2, n=>'b');
      my $c = $d->wire(x=>2, y=>0, X=>2, Y=>2, n=>'c');
      my $e = $d->wire(x=>0, y=>2, X=>1, Y=>1, n=>'e');
      my $f = $d->wire(x=>0, y=>3, X=>4, Y=>0, n=>'f');
      my $F = $d->wire(x=>1, y=>3, X=>3, Y=>0, n=>'F');

      is_deeply($d->levels, 1);
      my $g = $d->wire(x=>0, y=>0, X=>3, Y=>0, n=>'g');
      is_deeply($d->levels, 2);

      is_deeply($d->totalLength, 119);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

      is_deeply($d->levels, 2);


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
    ....S01...1..
    ......1...1..
    ......00001..
    END


      is_deeply(printPath($g->p), <<END);
    S...........F
    1...........1
    0000000000001
    END
      $d->svg (svg=>q(xy2), pngs=>2);
      $d->gds2(svg=>q/xy2/);
     }

<div>
    <img src="https://raw.githubusercontent.com/philiprbrenan/SiliconChipWiring/main/lib/Silicon/Chip/png/xy2.png">
</div>

<div>
    <img src="https://raw.githubusercontent.com/philiprbrenan/SiliconChipWiring/main/lib/Silicon/Chip/png/xy2_1.png">
</div>

<div>
    <img src="https://raw.githubusercontent.com/philiprbrenan/SiliconChipWiring/main/lib/Silicon/Chip/png/xy2_2.png">
</div>

## findShortestPath($diagram, $imageX, $imageY, $start, $finish)

Find the shortest path between two points in a two dimensional image stepping only from/to adjacent marked cells. The permissible steps are given in two imahes, one for x steps and one for y steps.

       Parameter  Description
    1  $diagram   Diagram
    2  $imageX    ImageX{x}{y}
    3  $imageY    ImageY{x}{y}
    4  $start     Start point
    5  $finish    Finish point

**Example:**

    if (1)
     {my %i = splitSplit(<<END);
    111111
    000111
    000011
    111111
    END

      my $p = [findShortestPath(undef, \%i, \%i, [0, 0], [0,3])];  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

      is_deeply(printPath($p), <<END);
    S0001
    ....1
    ....1
    F0000
    END
     }

# Visualize

Visualize a Silicon chip wiring diagrams

## print   ($d, %options)

Print a diagram

       Parameter  Description
    1  $d         Drawing
    2  %options   Options

**Example:**

    if (1)
     {my      $d = new(width=>2, height=>2);
      my $a = $d->wire(x=>1, y=>1, X=>2, Y=>1, n=>'a');
      my $b = $d->wire(x=>1, y=>2, X=>2, Y=>2, n=>'b');

      is_deeply($d->print, <<END);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

    Length: 10
       x,   y      X,   Y   L  Name    Path
       1,   1      2,   1   1  a       4,4,0  5,4,0  6,4,0  7,4,0  8,4
       1,   2      2,   2   1  b       4,8,0  5,8,0  6,8,0  7,8,0  8,8
    END
      is_deeply($d->printWire($a), "   1,   1      2,   1   1  a       4,4,0  5,4,0  6,4,0  7,4,0  8,4");
     }

## printWire   ($D, $W)

Print a wire to a string

       Parameter  Description
    1  $D         Drawing
    2  $W         Wire

**Example:**

    if (1)
     {my      $d = new(width=>2, height=>2);
      my $a = $d->wire(x=>1, y=>1, X=>2, Y=>1, n=>'a');
      my $b = $d->wire(x=>1, y=>2, X=>2, Y=>2, n=>'b');
      is_deeply($d->print, <<END);
    Length: 10
       x,   y      X,   Y   L  Name    Path
       1,   1      2,   1   1  a       4,4,0  5,4,0  6,4,0  7,4,0  8,4
       1,   2      2,   2   1  b       4,8,0  5,8,0  6,8,0  7,8,0  8,8
    END

      is_deeply($d->printWire($a), "   1,   1      2,   1   1  a       4,4,0  5,4,0  6,4,0  7,4,0  8,4");  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

     }

## printPath   ($P)

Print a path as a two dimensional character image

       Parameter  Description
    1  $P         Path

**Example:**

    if (1)
     {my      $d = new(width=>2, height=>2);
      my $a = $d->wire(x=>1, y=>1, X=>2, Y=>2, n=>'a');

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
    <img src="https://raw.githubusercontent.com/philiprbrenan/SiliconChipWiring/main/lib/Silicon/Chip/svg/xy1.svg">
</div>

<div>
    <img src="https://raw.githubusercontent.com/philiprbrenan/SiliconChipWiring/main/lib/Silicon/Chip/svg/xy1_1.svg">
</div>

## svg ($D, %options)

Draw the bus lines by level.

       Parameter  Description
    1  $D         Wiring diagram
    2  %options   Options

**Example:**

    if (1)
     {my      $d = new(width=>1, height=>2);
      my $w = $d->wire(x=>1, y=>1, X=>1, Y=>2, n=>'b');
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
    <img src="https://raw.githubusercontent.com/philiprbrenan/SiliconChipWiring/main/lib/Silicon/Chip/svg/y1.svg">
</div>

<div>
    <img src="https://raw.githubusercontent.com/philiprbrenan/SiliconChipWiring/main/lib/Silicon/Chip/svg/y1_1.svg">
</div>

## gds2($diagram, %options)

Draw the wires using GDS2

       Parameter  Description
    1  $diagram   Wiring diagram
    2  %options   Output file

**Example:**

    if (1)
     {my      $d = new(width=>1, height=>2);
      my $w = $d->wire(x=>1, y=>1, X=>1, Y=>2, n=>'b');
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
    <img src="https://raw.githubusercontent.com/philiprbrenan/SiliconChipWiring/main/lib/Silicon/Chip/svg/y1.svg">
</div>

<div>
    <img src="https://raw.githubusercontent.com/philiprbrenan/SiliconChipWiring/main/lib/Silicon/Chip/svg/y1_1.svg">
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

Level on which wore is drawn

#### levelX

{level}{x}{y} - available cells in X  - used cells are deleted. Normally if present the cell, if present has a positive value.  If it has a negative it is a temporary addition for the purpose of connecting the end points of the wires to the vertical vias.

#### levelY

{level}{x}{y} - available cells in Y

#### levels

Levels in use

#### n

Optional name

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

## newLevel($diagram, %options)

Make a new level and return its number

       Parameter  Description
    1  $diagram   Diagram
    2  %options   Options

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

1 [findShortestPath](#findshortestpath) - Find the shortest path between two points in a two dimensional image stepping only from/to adjacent marked cells.

2 [gds2](#gds2) - Draw the wires using GDS2

3 [length](#length) - Length of a wire in a diagram

4 [new](#new) - New wiring diagram.

5 [newLevel](#newlevel) - Make a new level and return its number

6 [numberOfWires](#numberofwires) - Number of wires in the diagram

7 [print](#print) - Print a diagram

8 [printCells](#printcells) - Print the cells and sub cells in a diagram

9 [printHash](#printhash) - Print a two dimensional hash

10 [printPath](#printpath) - Print a path as a two dimensional character image

11 [printWire](#printwire) - Print a wire to a string

12 [svg](#svg) - Draw the bus lines by level.

13 [svgLevel](#svglevel) - Draw the bus lines by level.

14 [totalLength](#totallength) - Total length of wires

15 [wire](#wire) - New wire on a wiring diagram.

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
