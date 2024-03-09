<div>
    <p><a href="https://github.com/philiprbrenan/SiliconChip"><img src="https://github.com/philiprbrenan/SiliconChip/workflows/Test/badge.svg"></a>
</div>

# Name

Silicon::Chip::Wiring - Wire up a [silicon](https://en.wikipedia.org/wiki/Silicon) [chip](https://en.wikipedia.org/wiki/Integrated_circuit) to combine [logic gates](https://en.wikipedia.org/wiki/Logic_gate) to transform software into hardware.

# Synopsis

<div>
    <p><img src="https://raw.githubusercontent.com/philiprbrenan/SiliconChipWiring/main/lib/Silicon/Chip/svg/square.svg">
</div>

# Description

Wire up a [silicon](https://en.wikipedia.org/wiki/Silicon) [chip](https://en.wikipedia.org/wiki/Integrated_circuit) to combine [logic gates](https://en.wikipedia.org/wiki/Logic_gate) to transform software into hardware.

Version 20240308.

The following sections describe the methods in each functional area of this
module.  For an alphabetic listing of all methods by name see [Index](#index).

# Construct

Create a Silicon chip wiring diagrams

## new (%options)

New wiring diagram

       Parameter  Description
    1  %options   Options

**Example:**

    if (1)

     {my $d = new;  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

      $d->wire(x=>1, y=>3, X=>3, Y=>1);
      $d->wire(x=>7, y=>3, X=>5, Y=>1);
      $d->wire(x=>1, y=>5, X=>3, Y=>7);
      $d->wire(x=>7, y=>5, X=>5, Y=>7);

      $d->wire(x=>1, y=>11, X=>3, Y=>9,  d=>1);
      $d->wire(x=>7, y=>11, X=>5, Y=>9,  d=>1);
      $d->wire(x=>1, y=>13, X=>3, Y=>15, d=>1);
      $d->wire(x=>7, y=>13, X=>5, Y=>15, d=>1);

      ok(!$d->wire(x=>1, y=>8, X=>2, Y=>10,  d=>1));
      $d->svg(file=>"square");
     }

## wire($D, %options)

New wire on wiring diagram

       Parameter  Description
    1  $D         Diagram
    2  %options   Options

**Example:**

    if (1)
     {my $d = new;

      $d->wire(x=>1, y=>3, X=>3, Y=>1);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲


      $d->wire(x=>7, y=>3, X=>5, Y=>1);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲


      $d->wire(x=>1, y=>5, X=>3, Y=>7);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲


      $d->wire(x=>7, y=>5, X=>5, Y=>7);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲



      $d->wire(x=>1, y=>11, X=>3, Y=>9,  d=>1);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲


      $d->wire(x=>7, y=>11, X=>5, Y=>9,  d=>1);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲


      $d->wire(x=>1, y=>13, X=>3, Y=>15, d=>1);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲


      $d->wire(x=>7, y=>13, X=>5, Y=>15, d=>1);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲



      ok(!$d->wire(x=>1, y=>8, X=>2, Y=>10,  d=>1));  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

      $d->svg(file=>"square");
     }

# Visualize

Visualize a Silicon chip wiring diagrams

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

#### wires

Wires on diagram

#### x

Start x position of wire

#### y

Start y position of wire

# Private Methods

## canLayX ($D, $W)

Confirm we can lay a wire in X

       Parameter  Description
    1  $D         Drawing
    2  $W         Wire

## canLayY ($D, $W)

Confirm we can lay a wire in Y

       Parameter  Description
    1  $D         Drawing
    2  $W         Wire

## svg ($D, %options)

Draw the bus lines.

       Parameter  Description
    1  $D         Wiring diagram
    2  %options   Options

# Index

1 [canLayX](#canlayx) - Confirm we can lay a wire in X

2 [canLayY](#canlayy) - Confirm we can lay a wire in Y

3 [new](#new) - New wiring diagram

4 [svg](#svg) - Draw the bus lines.

5 [wire](#wire) - New wire on wiring diagram

# Installation

This module is written in 100% Pure Perl and, thus, it is easy to read,
comprehend, use, modify and install via **cpan**:

    sudo cpan install Silicon::Chip::Wiring

# Author

[philiprbrenan@gmail.com](mailto:philiprbrenan@gmail.com)

[http://www.appaapps.com](http://www.appaapps.com)

# Copyright

Copyright (c) 2016-2023 Philip R Brenan.

This module is free software. It may be used, redistributed and/or modified
under the same terms as Perl itself.
