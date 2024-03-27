<div>
    <p><a href="https://github.com/philiprbrenan/SiliconChipWiring"><img src="https://github.com/philiprbrenan/SiliconChipWiring/workflows/Test/badge.svg"></a>
</div>

# Name

Silicon::Chip::Wiring - Wire up a [silicon](https://en.wikipedia.org/wiki/Silicon) [chip](https://en.wikipedia.org/wiki/Integrated_circuit) to combine [logic gates](https://en.wikipedia.org/wiki/Logic_gate) to transform software into hardware.

# Synopsis

## Wire up a silicon chip

<div>
    <p><img src="https://raw.githubusercontent.com/philiprbrenan/SiliconChipWiring/main/lib/Silicon/Chip/svg/square.svg">
</div>

## Automatic wiring around obstacles

<div>
    <p><img src="https://raw.githubusercontent.com/philiprbrenan/SiliconChipWiring/main/lib/Silicon/Chip/svg/wire3c_n_1.svg">
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

Version 20240308.

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

     {my  $d = new;  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

       ok $d->wire(x=>1, y=>3, X=>3, Y=>1);
       ok $d->wire(x=>7, y=>3, X=>5, Y=>1);
       ok $d->wire(x=>1, y=>5, X=>3, Y=>7);
       ok $d->wire(x=>7, y=>5, X=>5, Y=>7);

       ok $d->wire(x=>1, y=>11, X=>3, Y=>9,  d=>1);
       ok $d->wire(x=>7, y=>11, X=>5, Y=>9,  d=>1);
       ok $d->wire(x=>1, y=>13, X=>3, Y=>15, d=>1);
       ok $d->wire(x=>7, y=>13, X=>5, Y=>15, d=>1);

      nok $d->wire(x=>1, y=>8, X=>2, Y=>10,  d=>1);
          $d->svg(file=>"square");
     }

    if (1)
     {my $N = 3;

      my  $d = new;  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

      ok  $d->wire2(x=>$_, y=>1, X=>1+$_, Y=>1+$_) for 1..$N;
      $d->svg(file=>"layers");
      is_deeply($d->levels, 2);
     }

## wire($D, %options)

New wire on a wiring diagram.

       Parameter  Description
    1  $D         Diagram
    2  %options   Options

**Example:**

    if (1)
     {my  $d = new;

       ok $d->wire(x=>1, y=>3, X=>3, Y=>1);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲


       ok $d->wire(x=>7, y=>3, X=>5, Y=>1);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲


       ok $d->wire(x=>1, y=>5, X=>3, Y=>7);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲


       ok $d->wire(x=>7, y=>5, X=>5, Y=>7);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲



       ok $d->wire(x=>1, y=>11, X=>3, Y=>9,  d=>1);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲


       ok $d->wire(x=>7, y=>11, X=>5, Y=>9,  d=>1);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲


       ok $d->wire(x=>1, y=>13, X=>3, Y=>15, d=>1);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲


       ok $d->wire(x=>7, y=>13, X=>5, Y=>15, d=>1);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲



      nok $d->wire(x=>1, y=>8, X=>2, Y=>10,  d=>1);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

          $d->svg(file=>"square");
     }

    if (1)
     {my $N = 3;
      my  $d = new;
      ok  $d->wire2(x=>$_, y=>1, X=>1+$_, Y=>1+$_) for 1..$N;
      $d->svg(file=>"layers");
      is_deeply($d->levels, 2);
     }

## numberOfWires   ($D, %options)

Number of wires in the diagram

       Parameter  Description
    1  $D         Diagram
    2  %options   Options

**Example:**

    if (1)
     {my  $d = new;
      my $w = $d->wire(x=>1, y=>1, X=>2, Y=>3);
      is_deeply($d->length($w), 5);

      is_deeply($d->numberOfWires, 1);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

      nok $d->wire(x=>2, y=>1, X=>2, Y=>3);

      is_deeply($d->numberOfWires, 1);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

     }

## levels  ($D, %options)

Number of levels in the diagram

       Parameter  Description
    1  $D         Diagram
    2  %options   Options

**Example:**

    {my  $d = new;

## wire2   ($D, %options)

Try connecting two points by going along X first if that fails along Y first to see if a connection can in fact be made. Try at each level until we find the first level that we can make the connection at or create a new level to ensure that the connection is made.

       Parameter  Description
    1  $D         Diagram
    2  %options   Options

**Example:**

    if (1)
     {my  $d = new;
       ok $d->wire (x=>1, y=>1, X=>3, Y=>3);

       ok $d->wire2(x=>1, y=>3, X=>3, Y=>5);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲



          $d->svg(file=>"wire2");  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

     }

## wire3c  ($D, %options)

Connect two points by moving out from the source to **s** and from the target to **t** and then connect source to **s** to **t**  to target.

       Parameter  Description
    1  $D         Diagram
    2  %options   Options

**Example:**

    if (1)
     {my  $d = new;
      $d->wire(x=>3, y=>4, X=>4, Y=>4);
      $d->wire(x=>3, y=>5, X=>4, Y=>5);
      $d->wire(x=>3, y=>6, X=>4, Y=>6);
      $d->wire(x=>3, y=>7, X=>4, Y=>7);
      $d->wire(x=>3, y=>8, X=>4, Y=>8);

      my $c = $d->wire3c(x=>1, y=>6, X=>6, Y=>7);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

      is_deeply($c, [13,
        { d => 1, l => 1, x => 1, X => 6, Y => 9, y => 6 },
        { d => 1, l => 1, x => 6, X => 6, y => 9, Y => 7 },
      ]);

      $d->svg(file=>"wire3c_u");
     }

    if (1)
     {my  $d = new;
      $d->wire(x=>2, y=>2, X=>3, Y=>2);
      $d->wire(x=>2, y=>3, X=>3, Y=>3);
      $d->wire(x=>8, y=>2, X=>9, Y=>2);
      $d->wire(x=>8, y=>3, X=>9, Y=>3);

      $d->wire(x=>5, y=>4, X=>6, Y=>4);

      $d->wire(x=>2, y=>5, X=>3, Y=>5);
      $d->wire(x=>2, y=>6, X=>3, Y=>6);
      $d->wire(x=>8, y=>5, X=>9, Y=>5);
      $d->wire(x=>8, y=>6, X=>9, Y=>6);


      my $c = $d->wire3c(x=>2, y=>4, X=>8, Y=>4);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

      is_deeply($c, [13,
         { d => 0, l => 1, X => 4, x => 2, Y => 3, y => 4 },
         { d => 0, l => 1, x => 4, X => 7, y => 3, Y => 3 },
         { d => 1, l => 1, X => 8, x => 7, y => 3, Y => 4 },
      ]);

      $d->svg(file=>"wire3c_n");
     }

## startAtSamePoint($D, $a, $b)

Whether two wires start at the same point on the same level.

       Parameter  Description
    1  $D         Drawing
    2  $a         Wire
    3  $b         Wire

**Example:**

    if (1)
     {my  $d = new;
       ok (my $a = $d->wire(x=>1, y=>1, X=>5, Y=>3, d=>1));                         # First
       ok (my $b = $d->wire(x=>3, y=>2, X=>5, Y=>4, d=>1));
      nok (my $c = $d->wire(x=>3, y=>2, X=>7, Y=>3, d=>1));                         # X overlaps first but did not start at the same point as first
       ok (my $e = $d->wire(x=>3, y=>2, X=>7, Y=>4, d=>1));

      nok $d->startAtSamePoint($b, $a);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲


       ok $d->startAtSamePoint($b, $e);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

          $d->svg(file=>"overY2");
     }

## length  ($D, $w)

Length of a wire including the vertical connections

       Parameter  Description
    1  $D         Drawing
    2  $w         Wire

**Example:**

    if (1)
     {my  $d = new;
      my $w = $d->wire(x=>1, y=>1, X=>2, Y=>3);

      is_deeply($d->length($w), 5);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

      is_deeply($d->numberOfWires, 1);
      nok $d->wire(x=>2, y=>1, X=>2, Y=>3);
      is_deeply($d->numberOfWires, 1);
     }

## freeBoard   ($D, %options)

The free space in +X, -X, +Y, -Y given a point in a level in the diagram. The lowest low limit is zero, while an upper limit of [undef](https://perldoc.perl.org/functions/undef.html) implies unbounded.

       Parameter  Description
    1  $D         Drawing
    2  %options   Options

**Example:**

    if (1)
     {my  $d = new;
       ok $d->wire(x=>10, y=>30, X=>30, Y=>10);
       ok $d->wire(x=>70, y=>30, X=>50, Y=>10);
       ok $d->wire(x=>10, y=>50, X=>30, Y=>70);
       ok $d->wire(x=>70, y=>50, X=>50, Y=>70);
          $d->svg(file=>"freeBoardX");


       is_deeply([$d->freeBoard(x=>33, y=>30, l=>1)], [30, 50,     0, undef]);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲


       is_deeply([$d->freeBoard(x=>30, y=>47, l=>1)], [0,  undef, 30, 50]);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲


       is_deeply([$d->freeBoard(x=>40, y=>40, l=>1)], [0,  undef,  0, undef]);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

     }

    if (1)
     {my  $d = new;
       ok $d->wire(x=>10, y=>30, X=>30, Y=>10, d=>1);
       ok $d->wire(x=>70, y=>30, X=>50, Y=>10, d=>1);
       ok $d->wire(x=>10, y=>50, X=>30, Y=>70, d=>1);
       ok $d->wire(x=>70, y=>50, X=>50, Y=>70, d=>1);
          $d->svg(file=>"freeBoardY");


        is_deeply([$d->freeBoard(x=>33, y=>10, l=>1)], [30,    50, 0, undef]);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲


        is_deeply([$d->freeBoard(x=>5,  y=>10, l=>1)], [ 0,    10, 0, undef]);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲


        is_deeply([$d->freeBoard(x=>75, y=>10, l=>1)], [70, undef, 0, undef]);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲


        is_deeply([$d->freeBoard(x=>40, y=>40, l=>1)], [ 0, undef, 0, undef]);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

     }

# Visualize

Visualize a Silicon chip wiring diagrams

## printWire   ($D, $W)

Print a wire to a string

       Parameter  Description
    1  $D         Drawing
    2  $W         Wire

**Example:**

    if (1)
     {my  $d = new;
      my $w = $d->wire(x=>3, y=>4, X=>4, Y=>4);
      is_deeply($w, {d =>0, l=>1, x=>3, X=>4, Y=>4, y=>4});
     }

## svg ($D, %options)

Draw the bus lines by level.

       Parameter  Description
    1  $D         Wiring diagram
    2  %options   Options

**Example:**

    if (1)
     {my  $d = new;
       ok $d->wire(x=>1, y=>1, X=>3, Y=>3, d=>1);
      nok $d->wire(x=>1, y=>2, X=>5, Y=>7, d=>1);                                   # Overlaps previous wire but does not start at the same point
       ok $d->wire(x=>1, y=>1, X=>7, Y=>7, d=>1);

          $d->svg(file=>"overY1");  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

     }

# Hash Definitions

## Silicon::Chip::Wiring Definition

Wire

### Output fields

#### X

End   x position of wire

#### Y

End   y position of wire

#### d

The direction to draw first, x: 0, y:1

#### l

Level

#### wires

Wires on diagram

#### x

Start x position of wire

#### y

Start y position of wire

# Private Methods

## overlays($a, $b, $x, $y)

Check whether two segments overlay each other

       Parameter  Description
    1  $a         Start of first segment
    2  $b         End of first segment
    3  $x         Start of second segment
    4  $y         End of second segment

## canLay  ($d, $w, %options)

Confirm we can lay a wire in X and Y with out overlaying an existing wire.

       Parameter  Description
    1  $d         Drawing
    2  $w         Wire
    3  %options   Options

## canLayX ($D, $W, %options)

Confirm we can lay a wire in X with out overlaying an existing wire.

       Parameter  Description
    1  $D         Drawing
    2  $W         Wire
    3  %options   Options

## canLayY ($D, $W, %options)

Confirm we can lay a wire in Y with out overlaying an existing wire.

       Parameter  Description
    1  $D         Drawing
    2  $W         Wire
    3  %options   Options

## svgLevel($D, %options)

Draw the bus lines by level.

       Parameter  Description
    1  $D         Wiring diagram
    2  %options   Options

# Index

1 [canLay](#canlay) - Confirm we can lay a wire in X and Y with out overlaying an existing wire.

2 [canLayX](#canlayx) - Confirm we can lay a wire in X with out overlaying an existing wire.

3 [canLayY](#canlayy) - Confirm we can lay a wire in Y with out overlaying an existing wire.

4 [freeBoard](#freeboard) - The free space in +X, -X, +Y, -Y given a point in a level in the diagram.

5 [length](#length) - Length of a wire including the vertical connections

6 [levels](#levels) - Number of levels in the diagram

7 [new](#new) - New wiring diagram.

8 [numberOfWires](#numberofwires) - Number of wires in the diagram

9 [overlays](#overlays) - Check whether two segments overlay each other

10 [printWire](#printwire) - Print a wire to a string

11 [startAtSamePoint](#startatsamepoint) - Whether two wires start at the same point on the same level.

12 [svg](#svg) - Draw the bus lines by level.

13 [svgLevel](#svglevel) - Draw the bus lines by level.

14 [wire](#wire) - New wire on a wiring diagram.

15 [wire2](#wire2) - Try connecting two points by going along X first if that fails along Y first to see if a connection can in fact be made.

16 [wire3c](#wire3c) - Connect two points by moving out from the source to **s** and from the target to **t** and then connect source to **s** to **t**  to target.

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
