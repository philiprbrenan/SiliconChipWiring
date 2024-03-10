#!/usr/bin/perl -I/home/phil/perl/cpan/DataTableText/lib/ -I/home/phil/perl/cpan/SvgSimple/lib/
#-------------------------------------------------------------------------------
# Wiring up a silicon chip to transform software into hardware.
# Philip R Brenan at appaapps dot com, Appa Apps Ltd Inc., 2024
#-------------------------------------------------------------------------------
use v5.34;
package Silicon::Chip::Wiring;
our $VERSION = 20240308;
use warnings FATAL => qw(all);
use strict;
use Carp;
use Data::Dump qw(dump);
use Data::Table::Text qw(:all);
use Svg::Simple;

makeDieConfess;

my $debug = 1;                                                                  # Debug if set
sub debugMask {1}                                                               # Adds a grid to the drawing of a bus line

#D1 Construct                                                                   # Create a Silicon chip wiring diagram on one or more levels as necessary to make the connections requested.

sub new(%)                                                                      # New wiring diagram.
 {my (%options) = @_;                                                           # Options
  genHash(__PACKAGE__,                                                          # Wiring diagram
    %options,                                                                   # Options
    wires => [],                                                                # Wires on diagram
   );
 }

sub wire($%)                                                                    # New wire on a wiring diagram.
 {my ($D, %options) = @_;                                                       # Diagram, options

  my ($x, $X, $y, $Y, $d, $l) = @options{qw(x X y Y d l)};
  defined($x) or confess "x";
  defined($y) or confess "y";
  defined($X) or confess "X";
  defined($Y) or confess "Y";
  $x == $X and $y == $Y and confess "Start and end of connection are in the same cell";
  $d //= 0;
  $l ||= 1;

  my $w = genHash(__PACKAGE__,                                                  # Wire
    x => $x,                                                                    # Start x position of wire
    X => $X,                                                                    # End   x position of wire
    y => $y,                                                                    # Start y position of wire
    Y => $Y,                                                                    # End   y position of wire
    d => $d,                                                                    # The direction to draw first, x: 0, y:1
    l => $l,                                                                     # Level
   );

  return undef unless $D->canLayX($w) and $D->canLayY($w);                      # Confirm we can lay the wire
  push $D->wires->@*, $w;                                                       # Append wire to diagram

  $w
 }

sub levels($%)                                                                  # Number of levels in the diagram
 {my ($D, %options) = @_;                                                       # Diagram, options
  max(map {$_->l} $D->wires->@*) // 0;                                          # Largest level is the number of levels
 }

sub wire2($%)                                                                   # Try connecting two points by going along X first if that fails along Y first to see if a connection can in fact be made. Try at each level until we find the first level that we can make the connection at or create a new level to ensure that the connection is made.
 {my ($D, %options) = @_;                                                       # Diagram, options

  delete $options{d};
  my $L = $D->levels;
  for my $l(1..$L+1)                                                            # This loop ensures that the wire will either be placed on an existing level or added to a new level
   {my $a = $D->wire(%options, l=>$l);
    return $a if defined $a;
    my $b = $D->wire(%options, l=>$l, d=>1);
    return $b if defined $b;
   }
 }

sub startAtSamePoint($$$)                                                       # Whether two wires start at the same point on the same level.
 {my ($D, $a, $b) = @_;                                                         # Drawing, wire, wire
  my ($x, $y, $l) = @$a{qw(x y l)};
  my ($X, $Y, $L) = @$b{qw(x y l)};
  $l == $L and $x == $X and $y == $Y                                            # True if they start at the same point
 }

sub canLayX($$)                                                                 #P Confirm we can lay a wire in X with out overlaying an existing wire.
 {my ($D, $W) = @_;                                                             # Drawing, wire
  my ($x, $y, $X, $Y, $d, $l)         = @$W{qw(x y X Y d l)};

  for my $w($D->wires->@*)                                                      # Each wire
   {my ($xx, $yy, $XX, $YY, $dd, $ll) = @$w{qw(x y X Y d l)};
    next if $l != $ll or $D->startAtSamePoint($W, $w);                          # One output pin can drive many input pins, but each input pin can be driven by only one output pin
    if ($x >= $xx && $x <= $XX or $X >= $xx && $X <= $XX)                       # Overlap with this wire in X
     {if ($d == 0 and $dd == 0)
       {return 0 if $y == $yy;
        next;
       }
      if ($d == 0 and $dd == 1)
       {return 0 if $y == $YY;
        next;
       }
      if ($d == 1 and $dd == 0)
       {return 0 if $Y == $yy;
        next;
       }
      if ($d == 1 and $dd == 1)
       {return 0 if $Y == $YY;
        next;
       }
     }
   }
  1                                                                             # Did not overlay any existing X segment
 }

sub canLayY($$)                                                                 #P Confirm we can lay a wire in Y with out overlaying an existing wire.
 {my ($D, $W) = @_;                                                             # Drawing, wire
  my ($x, $y, $X, $Y, $d, $l)         = @$W{qw(x y X Y d l)};

  for my $w($D->wires->@*)                                                      # Each wire
   {my ($xx, $yy, $XX, $YY, $dd, $ll) = @$w{qw(x y X Y d l)};
    next if $l != $ll or $D->startAtSamePoint($W, $w);                          # One output pin can drive many input pins, but each input pin can be driven by only one output pin
    if ($y >= $yy && $y <= $YY or $y >= $YY && $y <= $yy or                     # Overlap with this wire in Y
        $Y >= $yy && $y <= $YY or $Y >= $YY && $Y <= $yy)
     {if ($d == 0 and $dd == 0)
       {return 0 if $X == $XX;
        next;
       }
      if ($d == 0 and $dd == 1)
       {return 0 if $X == $xx;
        next;
       }
      if ($d == 1 and $dd == 0)
       {return 0 if $x == $XX;
        next;
       }
      if ($d == 1 and $dd == 1)
       {return 0 if $x == $xx;
        next;
       }
     }
   }
  1                                                                             # Did not overlay any existing Y segment
 }

#D1 Visualize                                                                   # Visualize a Silicon chip wiring diagrams

sub svg($%)                                                                     # Draw the bus lines.
 {my ($D, %options) = @_;                                                       # Wiring diagram, options
  my $L = $options{level};                                                      # Option level:  draw the specified level else draw all levels

  my @defaults = (defaults=>                                                    # Default values
   {stroke_width => 1,
    opacity      =>0.75,
   });

  my $xs = "darkRed"; my $ys = "darkBlue";                                      # x,y colors
  my $svg = Svg::Simple::new(@defaults, %options, grid=>debugMask ? 1 : 0);     # Draw each wire via Svg. Grid set to 1 produces a grid that can be helpful debugging layout problems

  for my $w($D->wires->@*)                                                      # Each wire in X
   {my ($x, $y, $X, $Y, $d, $l) = @$w{qw(x y X Y d l)};
    next if $x == $X or defined($L) &&  $L != $l;                               # Must occupy space in this dimension and optionally be on the specified level
    if ($d)
     {if ($x > $X)
       {$svg->line(x1=>$X,   y1=>$Y+1/2, x2=>$x+1, y2=>$Y+1/2, stroke=>$xs);
       }
      else
       {$svg->line(x1=>$x,   y1=>$Y+1/2, x2=>$X+1, y2=>$Y+1/2, stroke=>$xs);
       }
     }
    else
     {if ($x > $X)
       {$svg->line(x1=>$X,   y1=>$y+1/2, x2=>$x+1, y2=>$y+1/2, stroke=>$xs);
       }
      else
       {$svg->line(x1=>$x,   y1=>$y+1/2, x2=>$X+1, y2=>$y+1/2, stroke=>$xs);
       }
     }
   }

  for my $w($D->wires->@*)                                                      # Each wire in Y
   {my ($x, $y, $X, $Y, $d, $l) = @$w{qw(x y X Y d l)};
    next if $y == $Y or defined($L) &&  $L != $l;                               # Must occupy space in this dimension and optionally be on the specified level
    if ($d)
     {if ($y < $Y)
       {$svg->line(x1=>$x+1/2, y1=>$y,   x2=>$x+1/2, y2=>$Y+1,   stroke=>$ys);
       }
     elsif ($y > $Y)                                                            # Avoid drawing Y wires of length 1
       {$svg->line(x1=>$x+1/2, y1=>$Y,   x2=>$x+1/2, y2=>$y+1,   stroke=>$ys);
       }
     }
    else
     {if ($y > $Y)
       {$svg->line(x1=>$X+1/2, y1=>$y+1, x2=>$X+1/2, y2=>$Y,     stroke=>$ys);
       }
      elsif ($y < $Y)                                                           # Avoid drawing Y wires of length 1
       {$svg->line(x1=>$X+1/2, y1=>$y,   x2=>$X+1/2, y2=>$Y+1,   stroke=>$ys);
       }
     }
   }

  for my $w($D->wires->@*)                                                      # Show start and end points of each wire
   {my ($x, $y, $X, $Y, $d, $l) = @$w{qw(x y X Y d l)};
    next if defined($L) &&  $L != $l;                               # Must occupy space in this dimension and optionally be on the specified level
    $svg->rect(x=>$x+1/4, y=>$y+1/4, width=>1/2, height=>1/2, fill=>"green",  opacity=>1);
    $svg->rect(x=>$X+1/4, y=>$Y+1/4, width=>1/2, height=>1/2, fill=>"yellow", opacity=>1);
   }

  my $t = $svg->print;                                                          # Text of svg

  if (my $f = $options{file})                                                   # Optionally write to an svg file
   {owf(fpe(q(svg), $f, q(svg)), $t)
   }

  $t
 }

#D0
#-------------------------------------------------------------------------------
# Export
#-------------------------------------------------------------------------------

use Exporter qw(import);

use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

# containingFolder

@ISA          = qw(Exporter);
@EXPORT       = qw();
@EXPORT_OK    = qw(connectBits connectWords n nn setBits setWords);
%EXPORT_TAGS = (all=>[@EXPORT, @EXPORT_OK]);

#Images https://raw.githubusercontent.com/philiprbrenan/SiliconChip/main/lib/Silicon/svg/

=pod

=encoding utf-8

=for html <p><a href="https://github.com/philiprbrenan/SiliconChip"><img src="https://github.com/philiprbrenan/SiliconChip/workflows/Test/badge.svg"></a>

=head1 Name

Silicon::Chip::Wiring - Wire up a L<silicon|https://en.wikipedia.org/wiki/Silicon> L<chip|https://en.wikipedia.org/wiki/Integrated_circuit> to combine L<logic gates|https://en.wikipedia.org/wiki/Logic_gate> to transform software into hardware.

=head1 Synopsis

=for html <p><img src="https://raw.githubusercontent.com/philiprbrenan/SiliconChipWiring/main/lib/Silicon/Chip/svg/square.svg">

=head1 Description

Wire up a L<silicon|https://en.wikipedia.org/wiki/Silicon> L<chip|https://en.wikipedia.org/wiki/Integrated_circuit> to combine L<logic gates|https://en.wikipedia.org/wiki/Logic_gate> to transform software into hardware.


Version 20240308.


The following sections describe the methods in each functional area of this
module.  For an alphabetic listing of all methods by name see L<Index|/Index>.



=head1 Construct

Create a Silicon chip wiring diagrams

=head2 new (%options)

New wiring diagram.

     Parameter  Description
  1  %options   Options

B<Example:>


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


=head2 wire($D, %options)

New wire on a wiring diagram.

     Parameter  Description
  1  $D         Diagram
  2  %options   Options

B<Example:>


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


=head1 Visualize

Visualize a Silicon chip wiring diagrams

=head2 svg ($D, %options)

Draw the bus lines.

     Parameter  Description
  1  $D         Wiring diagram
  2  %options   Options

B<Example:>


  if (1)
   {my $d = new;
    $d->wire(x=>1, y=>1, X=>1, Y=>3);
    $d->wire(x=>1, y=>2, X=>1, Y=>4);

    $d->svg(file=>"overY1");  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

   }



=head1 Hash Definitions




=head2 Silicon::Chip::Wiring Definition


Wire




=head3 Output fields


=head4 X

End   x position of wire

=head4 Y

End   y position of wire

=head4 d

The direction to draw first, x: 0, y:1

=head4 wires

Wires on diagram

=head4 x

Start x position of wire

=head4 y

Start y position of wire



=head1 Private Methods

=head2 canLayX ($D, $W)

Confirm we can lay a wire in X

     Parameter  Description
  1  $D         Drawing
  2  $W         Wire

=head2 canLayY ($D, $W)

Confirm we can lay a wire in Y

     Parameter  Description
  1  $D         Drawing
  2  $W         Wire


=head1 Index


1 L<canLayX|/canLayX> - Confirm we can lay a wire in X

2 L<canLayY|/canLayY> - Confirm we can lay a wire in Y

3 L<new|/new> - New wiring diagram.

4 L<svg|/svg> - Draw the bus lines.

5 L<wire|/wire> - New wire on a wiring diagram.

=head1 Installation

This module is written in 100% Pure Perl and, thus, it is easy to read,
comprehend, use, modify and install via B<cpan>:

  sudo cpan install Silicon::Chip::Wiring

=head1 Author

L<philiprbrenan@gmail.com|mailto:philiprbrenan@gmail.com>

L<http://www.appaapps.com|http://www.appaapps.com>

=head1 Copyright

Copyright (c) 2016-2023 Philip R Brenan.

This module is free software. It may be used, redistributed and/or modified
under the same terms as Perl itself.

=cut

goto finish if caller;
clearFolder(q(svg), 99);                                                        # Clear the output svg folder
my $start = time;
eval "use Test::More";
eval "Test::More->builder->output('/dev/null')" if -e q(/home/phil/);
eval {goto latest};

my sub  ok($)        {!$_[0] and confess; &ok( $_[0])}
my sub nok($)        {&ok(!$_[0])}
my sub is_deeply($$) {&is_deeply(@_)}

# Tests

if (1)
 {my  $d = new;                                                                 #Tlevels
   ok $d->wire(x=>1, y=>1, X=>3, Y=>3);
  nok $d->wire(x=>2, y=>1, X=>5, Y=>5);                                         # X overlaps and does not start at the same point
   ok $d->wire(x=>1, y=>1, X=>7, Y=>7);
      $d->svg(file=>"overX1");
   is_deeply $d->levels, 1;
 }

if (1)
 {my  $d = new;
   ok $d->wire(x=>1, y=>1, X=>3, Y=>5);                                         # First
   ok $d->wire(x=>2, y=>3, X=>4, Y=>5);
  nok $d->wire(x=>2, y=>3, X=>3, Y=>7);                                         # Y overlaps first but did not start at the same point as first
      $d->svg(file=>"overX2");
 }

if (1)                                                                          #Tsvg
 {my  $d = new;
   ok $d->wire(x=>1, y=>1, X=>3, Y=>3, d=>1);
  nok $d->wire(x=>1, y=>2, X=>5, Y=>7, d=>1);                                   # Overlaps previous wire but does not start at the same point
   ok $d->wire(x=>1, y=>1, X=>7, Y=>7, d=>1);
      $d->svg(file=>"overY1");
 }

if (1)                                                                          #TstartAtSamePoint
 {my  $d = new;
   ok (my $a = $d->wire(x=>1, y=>1, X=>5, Y=>3, d=>1));                         # First
   ok (my $b = $d->wire(x=>3, y=>2, X=>5, Y=>4, d=>1));
  nok (my $c = $d->wire(x=>3, y=>2, X=>7, Y=>3, d=>1));                         # X overlaps first but did not start at the same point as first
   ok (my $e = $d->wire(x=>3, y=>2, X=>7, Y=>4, d=>1));
  nok $d->startAtSamePoint($b, $a);
   ok $d->startAtSamePoint($b, $e);
      $d->svg(file=>"overY2");
 }

if (1)                                                                          #Twire #Tnew
 {my  $d = new;
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

if (1)                                                                          #Twire2
 {my  $d = new;
   ok $d->wire (x=>1, y=>1, X=>3, Y=>3);
   ok $d->wire2(x=>1, y=>3, X=>3, Y=>5);

      $d->svg(file=>"wire2");
 }

#latest:;
if (1)                                                                          #Twire #Tnew
 {my $N = 3;
  my  $d = new;
  ok  $d->wire2(x=>$_, y=>1, X=>1+$_, Y=>1+$_) for 1..$N;
  $d->svg(file=>"layers");
  my $L = $d->levels;
  is_deeply $L, 2;
  $d->svg(file=>"layers$_", level=>$_) for 1..$L;
 }

&done_testing;
finish: 1
