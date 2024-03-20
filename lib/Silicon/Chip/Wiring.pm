#!/usr/bin/perl -I/home/phil/perl/cpan/DataTableText/lib/ -I/home/phil/perl/cpan/SvgSimple/lib/  -I/home/phil/perl/cpan/Math-Intersection-Circle-Line/lib
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

my $debug = 0;                                                                  # Debug if set
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
  $d //= 0;                                                                     # Direction 0 - x  first, 1 - y first
  $l ||= 1;                                                                     # Level

  my $w = genHash(__PACKAGE__,                                                  # Wire
    x => $x,                                                                    # Start x position of wire
    X => $X,                                                                    # End   x position of wire
    y => $y,                                                                    # Start y position of wire
    Y => $Y,                                                                    # End   y position of wire
    d => $d,                                                                    # The direction to draw first, x: 0, y:1
    l => $l,                                                                    # Level
   );

  return undef unless $options{force} or $D->canLay($w, %options);              # Confirm we can lay the wire unless we are using force
  return $w if defined $options{noplace};                                       # Do not place the wire on the diagram
  push $D->wires->@*, $w;                                                       # Append wire to diagram
  $w
 }

sub numberOfWires($%)                                                           # Number of wires in the diagram
 {my ($D, %options) = @_;                                                       # Diagram, options
  scalar $D->wires->@*
 }

sub levels($%)                                                                  # Number of levels in the diagram
 {my ($D, %options) = @_;                                                       # Diagram, options
  max(map {$_->l} $D->wires->@*) // 0;                                          # Largest level is the number of levels
 }

sub overlays($$$$)                                                              #P Check whether two segments overlay each other
 {my ($a, $b, $x, $y) = @_;                                                     # Start of first segment, end of first segment, start of second segment, end of second segment
  ($a, $b) = ($b, $a) if $a > $b;
  ($x, $y) = ($y, $x) if $x > $y;
   $a <= $y and $b >= $x;
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

sub wire3c($%)                                                                  # Connect two points by moving out from the source to B<s> and from the target to B<t> and then connect source to B<s> to B<t>  to target.
 {my ($D, %options) = @_;                                                       # Diagram, options
  my ($px, $py, $pX, $pY) = @options{qw(x y X Y)};                              # Points to connect
  my $N = $options{spread} // 4;                                                # How far we should spread out from the source and target in search of a better connection. Beware: the search takes N**4 steps
  $px == $pX and $py == $pY and confess "Source == target";                     # Confirm that we are trying to connect separate points

  my $C;                                                                        # The cost of the shortest connecting C wire
  my sub minCost(@)                                                             # Check for lower cost connections
   {my (@w) = @_;                                                               # Wires
    my $c = 0; $c += $D->length($_) for @w;                                     # Sum costs
    $C = [$c, @w] if !defined($C) or $c < $$C[0];                               # Lower cost connection?
   }

  my $levels = $D->levels;                                                      # Levels

  for my $l(1..$levels)                                                         # Each level
   {for my $d(0..1)                                                             # Check for a direct connection at this level
     {if (my $w = $D->wire(x=>$px, y=>$py, X=>$pX, Y=>$pY, l=>$l, d=>$d, noplace=>1)) # Can we reach the source jump point from the source?
       {minCost($w);                                                            # Cost of the connection
       }
     }

    my $sx1 = max 0, $px - $N;                                                  # Source jump point search start in x
    my $sy1 = max 0, $py - $N;                                                  # Source jump point search start in y
    my $sx2 =        $px + $N;                                                  # Source jump point search end   in x
    my $sy2 =        $py + $N;                                                  # Source jump point search end   in y

    for     my $sx($sx1..$sx2)                                                  # Source jump placements in x
     {for   my $sy($sy1..$sy2)                                                  # Source jump placements in y
       {for my $d(0..1)                                                         # Direction
         {next if $sx == $px and $sy == $py;                                    # Avoid using the source or target as the jump point
          next if $sx == $pX and $sy == $pY;
          my $sw = $D->wire(x=>$px, y=>$py, X=>$sx, Y=>$sy, l=>$l, d=>$d, noplace=>1); # Can we reach the source jump point from the source?
          next unless defined $sw;

          my $tx1 = max 0, $pX - $N;                                            # Target jump point search start in x
          my $ty1 = max 0, $pY - $N;                                            # Target jump point search start in y
          my $tx2 =        $pX + $N;                                            # Target jump point search end   in x
          my $ty2 =        $pY + $N;                                            # Target jump point search end   in y
          for     my $tx($tx1..$tx2)                                            # Target jump placements in x
           {for   my $ty($ty1..$ty2)                                            # Target jump placements in y
             {for my $d(0..1)                                                   # Direction
               {next if $tx == $px and $ty == $py;                              # Avoid using the source or target as the jump point
                next if $tx == $pX and $ty == $pY;
                my $tw = $D->wire (x=>$tx, y=>$ty, X=>$pX, Y=>$pY, l=>$l, d=>$d, noplace=>1); # Can we reach the target jump point from the target
                next unless defined $tw;

                if ($sx == $tx and $sy == $ty)                                  # Identical jump points
                 {my $c = $D->length($sw) + $D->length($tw);                    # Cost of this connection
                  minCost($sw, $tw);                                            # Lower cost?
                 }
                elsif (my $Sw = $D->wire(x=>$px, y=>$py, X=>$tx, Y=>$ty, l=>$l, d=>$d, noplace=>1)) # Can we reach the target jump point directly from the source
                 {my $c = $D->length($Sw) + $D->length($tw);                    # Cost of this connection
                  minCost($Sw, $tw);                                            # Lower cost?
                 }
                elsif (my $Tw = $D->wire(x=>$sx, y=>$sy, X=>$pX, Y=>$pY, l=>$l, d=>$d, noplace=>1)) # Can we reach the target  directly from the source jump point
                 {my $c = $D->length($sw) + $D->length($Tw);                    # Cost of this connection
                  minCost($sw, $Tw);                                            # Lower cost?
                 }
                else                                                            # Differing jump points
                 {for my $d(0..1)                                               # Direction
                   {if (my $stw = $D->wire(x=>$sx, y=>$sy, X=>$tx, Y=>$ty, l=>$l, d=>$d, noplace=>1)) # Can we reach the target jump point from the source jump point
                     {my $c = $D->length($sw) + $D->length($tw) + $D->length($stw); # Cost of this connection including the vertical connections
                      minCost($sw, $stw, $tw);                                  # Lower cost?
                     }
                   }
                 }
               }
             }
           }
         }
       }
     }
   }
  return $C if defined $options{noplace};                                       # Do not place the wire on the diagram
  return $D->wire(%options, l=>$levels+1) unless defined $C;                    # No connection possible on any existing level, so start a new level and connect there
  if ($C)                                                                       # Create the wires
   {my @C = @$C; shift @C;
    for my $i(keys @C)
     {my $c = $C[$i];
      my $w = $D->wire(%$c, force=>1);                                          # Otherwise the central wire might not connect to the other wires and it might inavertantly start on another wores start point.  Ine way r=tp resolvethis might be to add a fan ouytt capability so that thre is never ever more than one connection between a pair of pins which would prevent an output pin from ever driving more than one input pin.
     }
   }
  $C
 }

sub startAtSamePoint($$$)                                                       # Whether two wires start at the same point on the same level.
 {my ($D, $a, $b) = @_;                                                         # Drawing, wire, wire
  my ($x, $y, $l) = @$a{qw(x y l)};
  my ($X, $Y, $L) = @$b{qw(x y l)};
  $l == $L and $x == $X and $y == $Y                                            # True if they start at the same point
 }

sub length($$)                                                                  # Length of a wire including the vertical connections
 {my ($D, $w) = @_;                                                             # Drawing, wire
  my ($x, $y, $X, $Y) = @$w{qw(x y X Y)};
  my $dx = abs($X - $x); my $dy = abs($Y - $y);
  return 1 + $dx unless $dy;
  return 1 + $dy unless $dx;
  2 + $dx + $dy
 }

sub totalLength($%)                                                             # Total length of all the wires
 {my ($D, %options) = @_;                                                       # Drawing, options

  my $l = 0;
  for my $w($D->wires->@*)                                                      # Each wire
   {$l += $D->length($w);
   }
  $l
 }

sub freeBoard($%)                                                               # The free space in +X, -X, +Y, -Y given a point in a level in the diagram. The lowest low limit is zero, while an upper limit of L<undef> implies unbounded.
 {my ($D, %options) = @_;                                                       # Drawing, options
  my ($x, $y, $l) = @options{qw(x y l)};

  my $mx = 0; my $Mx; my $my = 0; my $My;

  for my $w($D->wires->@*)                                                      # Each wire
   {my ($xx, $yy, $XX, $YY, $dd, $ll) = @$w{qw(x y X Y d l)};
    next if $l != $ll;                                                          # Same level
    if ($dd == 0)                                                               # X first
     {if ($yy == $y)                                                            # Same y
       {if ($xx == $XX && $x == $xx or $xx < $XX && $x >= $xx && $x <= $XX or $xx > $XX && $x >= $xx && $x <= $XX)                       # Overlap with this wire in X
         {$mx = $Mx = 0;                                                        # X is first and we are inside
         }
        elsif ($x < $xx)                                                        # The x range is above
         {$Mx = min($xx, $XX, defined($Mx) ? $Mx : $xx);                        # Smallest element of range above
         }
        elsif ($x > $xx)                                                        # The x range is below
         {$mx = max($xx, $XX, defined($mx) ? $mx : $xx);                        # Largest element of range below
         }
       }
      if ($XX == $x)                                                            # Same x
       {if ($yy == $YY && $y == $yy or $yy < $YY && $y >= $yy && $y <= $YY or $yy > $YY && $y >= $yy && $y <= $YY)                       # Overlap with this wire in Y
         {$my = $My = 0;                                                        # Y is first and we are inside
         }
        elsif ($y < $yy)                                                        # The y range is above
         {$My = min($yy, $YY, defined($My) ? $My : $yy);                        # Smallest element of range above
         }
        elsif ($y > $yy)                                                        # The y range is below
         {$my = max($yy, $YY, defined($my) ? $my : $yy);                        # Largest element of range below
         }
       }
     }
    else                                                                        # Y first
     {if ($xx == $x)                                                            # Same y
       {if ($yy == $YY && $y == $yy or $yy < $YY && $y >= $yy && $y <= $YY or $yy > $YY && $y >= $yy && $y <= $YY)                       # Overlap with this wire in Y
         {$my = $My = 0;                                                        # Y is first and we are inside
         }
        elsif ($y < $yy)                                                        # The y range is above
         {$My = min($yy, $YY, defined($My) ? $My : $yy);                        # Smallest element of range above
         }
        elsif ($y > $yy)                                                        # The y range is below
         {$my = may($yy, $YY, defined($my) ? $my : $yy);                        # Largest element of range below
         }
       }
      if ($YY == $y)                                                            # Same x
       {if ($xx == $XX && $x == $xx or $xx < $XX && $x >= $xx && $x <= $XX or $xx > $XX && $x >= $xx && $x <= $XX)                       # Overlap with this wire in X
         {$mx = $Mx = 0;                                                        # X is first and we are inside
         }
        elsif ($x < $xx)                                                        # The x range is above
         {$Mx = min($xx, $XX, defined($Mx) ? $Mx : $xx);                        # Smallest element of range above
         }
        elsif ($x > $xx)                                                        # The x range is below
         {$mx = max($xx, $XX, defined($mx) ? $mx : $xx);                        # Largest element of range below
         }
       }
     }
   }
  ($mx, $Mx, $my, $My)                                                          # Did not overlay any existing X segment
 }

sub canLay($$%)                                                                 #P Confirm we can lay a wire in X and Y with out overlaying an existing wire.
 {my ($d, $w, %options) = @_;                                                   # Drawing, wire, options
  $d->canLayX($w, %options) and $d->canLayY($w, %options);                      # Confirm we can lay the wire
 }

sub canLayX($$%)                                                                #P Confirm we can lay a wire in X with out overlaying an existing wire.
 {my ($D, $W, %options) = @_;                                                   # Drawing, wire, options
  my ($x, $y, $X, $Y, $d, $l)         = @$W{qw(x y X Y d l)};

  for my $w($D->wires->@*)                                                      # Each wire
   {my ($xx, $yy, $XX, $YY, $dd, $ll) = @$w{qw(x y X Y d l)};
    next if $l != $ll;

    if (overlays($x, $X, $xx, $XX))                                             # Possibly overlap with this wire in X
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

sub canLayY($$%)                                                                #P Confirm we can lay a wire in Y with out overlaying an existing wire.
 {my ($D, $W, %options) = @_;                                                   # Drawing, wire, options
  my ($x, $y, $X, $Y, $d, $l)         = @$W{qw(x y X Y d l)};

  for my $w($D->wires->@*)                                                      # Each wire
   {my ($xx, $yy, $XX, $YY, $dd, $ll) = @$w{qw(x y X Y d l)};
    next if $l != $ll;                                                          # One output pin can drive many input pins, but each input pin can be driven by only one output pin

    if (overlays($y, $Y, $yy, $YY))                                             # Possibly overlap with this wire in X
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

sub printWire($$)                                                               # Print a wire to a string
 {my ($D, $W) = @_;                                                             # Drawing, wire
  my ($x, $y, $X, $Y, $l, $d) = @$W{qw(x y X Y l d)};
  sprintf "%4d,%4d   %4d,%4d  %2d  %d", $x, $y, $X, $Y, $l, $d
 }

sub svg($%)                                                                     # Draw the bus lines by level.
 {my ($D, %options) = @_;                                                       # Wiring diagram, options
  if (defined($options{level}))                                                 # Draw the specified level
   {$D->svgLevel(%options);
   }
  else                                                                          # Draw all levels
   {my $L = $D->levels;
    my $F = $options{file} // '';                                               # File to write to  minus extension of svg
    my @s;
    for my $l(1..$L)
     {push @s, $D->svgLevel(%options, level=>$l, $F ? (file=>"${F}_$l") : ());  # Write each level into a separate file
     }
    @s
   }
 }

sub svgLevel($%)                                                                #P Draw the bus lines by level.
 {my ($D, %options) = @_;                                                       # Wiring diagram, options
  defined(my $L = $options{level}) or confess "level";                          # Draw the specified level

  my @defaults = (defaults=>                                                    # Default values
   {stroke_width => 0.5,
    opacity      => 0.75,
   });

  my $xs = "darkRed"; my $ys = "darkBlue";                                      # x,y colors
  my $svg = Svg::Simple::new(@defaults, %options, grid=>debugMask ? 1 : 0);     # Draw each wire via Svg. Grid set to 1 produces a grid that can be helpful debugging layout problems

  for my $w($D->wires->@*)                                                      # Each wire in X
   {my ($x, $y, $X, $Y, $d, $l) = @$w{qw(x y X Y d l)};
    next if $x == $X or defined($L) &&  $L != $l;                               # Must occupy space in this dimension and optionally be on the specified level
    if ($d)
     {if ($x > $X)
       {$svg->line(x1=>$X+1/4,   y1=>$Y+1/2, x2=>$x+3/4, y2=>$Y+1/2, stroke=>$xs);
       }
      else
       {$svg->line(x1=>$x+1/4,   y1=>$Y+1/2, x2=>$X+3/4, y2=>$Y+1/2, stroke=>$xs);
       }
     }
    else
     {if ($x > $X)
       {$svg->line(x1=>$X+1/4,   y1=>$y+1/2, x2=>$x+3/4, y2=>$y+1/2, stroke=>$xs);
       }
      else
       {$svg->line(x1=>$x+1/4,   y1=>$y+1/2, x2=>$X+3/4, y2=>$y+1/2, stroke=>$xs);
       }
     }
   }

  for my $w($D->wires->@*)                                                      # Each wire in Y
   {my ($x, $y, $X, $Y, $d, $l) = @$w{qw(x y X Y d l)};
    next if $y == $Y or defined($L) &&  $L != $l;                               # Must occupy space in this dimension and optionally be on the specified level
    if ($d)
     {if ($y < $Y)
       {$svg->line(x1=>$x+1/2, y1=>$y+1/4,   x2=>$x+1/2, y2=>$Y+3/4,   stroke=>$ys);
       }
     elsif ($y > $Y)                                                            # Avoid drawing Y wires of length 1
       {$svg->line(x1=>$x+1/2, y1=>$Y+1/4,   x2=>$x+1/2, y2=>$y+3/4,   stroke=>$ys);
       }
     }
    else
     {if ($y > $Y)
       {$svg->line(x1=>$X+1/2, y1=>$Y+1/4,   x2=>$X+1/2, y2=>$y+3/4,   stroke=>$ys);
       }
      elsif ($y < $Y)                                                           # Avoid drawing Y wires of length 1
       {$svg->line(x1=>$X+1/2, y1=>$y+1/4,   x2=>$X+1/2, y2=>$Y+3/4,   stroke=>$ys);
       }
     }
   }

  for my $w($D->wires->@*)                                                      # Show start and end points of each wire
   {my ($x, $y, $X, $Y, $d, $l) = @$w{qw(x y X Y d l)};
    next if defined($L) &&  $L != $l;                                           # Must occupy space in this dimension and optionally be on the specified level
    $svg->rect(x=>$x+1/4, y=>$y+1/4, width=>1/2, height=>1/2, fill=>"green",  opacity=>1);
    $svg->rect(x=>$X+1/4, y=>$Y+1/4, width=>1/2, height=>1/2, fill=>"yellow", opacity=>1);
   }

  my $t = $svg->print;                                                          # Text of svg

  if (my $f = $options{file})                                                   # Optionally write to an svg file
   {owf(fpe($f, q(svg)), $t)
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
@EXPORT_OK    = qw();
%EXPORT_TAGS = (all=>[@EXPORT, @EXPORT_OK]);

#Images https://raw.githubusercontent.com/philiprbrenan/SiliconChipWiring/main/lib/Silicon/Chip/svg/

=pod

=encoding utf-8

=for html <p><a href="https://github.com/philiprbrenan/SiliconChipWiring"><img src="https://github.com/philiprbrenan/SiliconChipWiring/workflows/Test/badge.svg"></a>

=head1 Name

Silicon::Chip::Wiring - Wire up a L<silicon|https://en.wikipedia.org/wiki/Silicon> L<chip|https://en.wikipedia.org/wiki/Integrated_circuit> to combine L<logic gates|https://en.wikipedia.org/wiki/Logic_gate> to transform software into hardware.

=head1 Synopsis

=head2 Wire up a silicon chip

=for html <p><img src="https://raw.githubusercontent.com/philiprbrenan/SiliconChipWiring/main/lib/Silicon/Chip/svg/square.svg">


=head2 Automatic wiring around obstacles

=for html <p><img src="https://raw.githubusercontent.com/philiprbrenan/SiliconChipWiring/main/lib/Silicon/Chip/svg/wire3c_n_1.svg">

=head1 Description

Wire up a L<silicon|https://en.wikipedia.org/wiki/Silicon> L<chip|https://en.wikipedia.org/wiki/Integrated_circuit> to combine L<logic gates|https://en.wikipedia.org/wiki/Logic_gate> to transform software into hardware.


Version 20240308.


The following sections describe the methods in each functional area of this
module.  For an alphabetic listing of all methods by name see L<Index|/Index>.



=head1 Construct

Create a Silicon chip wiring diagram on one or more levels as necessary to make the connections requested.

=head2 new (%options)

New wiring diagram.

     Parameter  Description
  1  %options   Options

B<Example:>


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
        $d->svg(file=>"svg/square");
   }

  if (1)
   {my $N = 3;

    my  $d = new;  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

    ok  $d->wire2(x=>$_, y=>1, X=>1+$_, Y=>1+$_) for 1..$N;
    $d->svg(file=>"svg/layers");
    is_deeply($d->levels, 2);
   }


=head2 wire($D, %options)

New wire on a wiring diagram.

     Parameter  Description
  1  $D         Diagram
  2  %options   Options

B<Example:>


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

        $d->svg(file=>"svg/square");
   }

  if (1)
   {my $N = 3;
    my  $d = new;
    ok  $d->wire2(x=>$_, y=>1, X=>1+$_, Y=>1+$_) for 1..$N;
    $d->svg(file=>"svg/layers");
    is_deeply($d->levels, 2);
   }


=head2 numberOfWires   ($D, %options)

Number of wires in the diagram

     Parameter  Description
  1  $D         Diagram
  2  %options   Options

B<Example:>


  if (1)
   {my  $d = new;
    my $w = $d->wire(x=>1, y=>1, X=>2, Y=>3);
    is_deeply($d->length($w), 5);

    is_deeply($d->numberOfWires, 1);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

    nok $d->wire(x=>2, y=>1, X=>2, Y=>3);

    is_deeply($d->numberOfWires, 1);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

   }


=head2 levels  ($D, %options)

Number of levels in the diagram

     Parameter  Description
  1  $D         Diagram
  2  %options   Options

B<Example:>


   {my  $d = new;


=head2 wire2   ($D, %options)

Try connecting two points by going along X first if that fails along Y first to see if a connection can in fact be made. Try at each level until we find the first level that we can make the connection at or create a new level to ensure that the connection is made.

     Parameter  Description
  1  $D         Diagram
  2  %options   Options

B<Example:>


  if (1)
   {my  $d = new;
     ok $d->wire (x=>1, y=>1, X=>3, Y=>3);

     ok $d->wire2(x=>1, y=>3, X=>3, Y=>5);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲



        $d->svg(file=>"svg/wire2");  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

   }


=head2 wire3c  ($D, %options)

Connect two points by moving out from the source to B<s> and from the target to B<t> and then connect source to B<s> to B<t>  to target.

     Parameter  Description
  1  $D         Diagram
  2  %options   Options

B<Example:>


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

    $d->svg(file=>"svg/wire3c_u");
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

    $d->svg(file=>"svg/wire3c_n");
   }


=head2 startAtSamePoint($D, $a, $b)

Whether two wires start at the same point on the same level.

     Parameter  Description
  1  $D         Drawing
  2  $a         Wire
  3  $b         Wire

B<Example:>


  if (1)
   {my  $d = new;
     ok (my $a = $d->wire(x=>1, y=>1, X=>5, Y=>3, d=>1));                         # First
     ok (my $b = $d->wire(x=>3, y=>2, X=>5, Y=>4, d=>1));
    nok (my $c = $d->wire(x=>3, y=>2, X=>7, Y=>3, d=>1));                         # X overlaps first but did not start at the same point as first
     ok (my $e = $d->wire(x=>3, y=>2, X=>7, Y=>4, d=>1));

    nok $d->startAtSamePoint($b, $a);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲


     ok $d->startAtSamePoint($b, $e);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

        $d->svg(file=>"svg/overY2");
   }


=head2 length  ($D, $w)

Length of a wire including the vertical connections

     Parameter  Description
  1  $D         Drawing
  2  $w         Wire

B<Example:>


  if (1)
   {my  $d = new;
    my $w = $d->wire(x=>1, y=>1, X=>2, Y=>3);

    is_deeply($d->length($w), 5);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

    is_deeply($d->numberOfWires, 1);
    nok $d->wire(x=>2, y=>1, X=>2, Y=>3);
    is_deeply($d->numberOfWires, 1);
   }


=head2 freeBoard   ($D, %options)

The free space in +X, -X, +Y, -Y given a point in a level in the diagram. The lowest low limit is zero, while an upper limit of L<undef|https://perldoc.perl.org/functions/undef.html> implies unbounded.

     Parameter  Description
  1  $D         Drawing
  2  %options   Options

B<Example:>


  if (1)
   {my  $d = new;
     ok $d->wire(x=>10, y=>30, X=>30, Y=>10);
     ok $d->wire(x=>70, y=>30, X=>50, Y=>10);
     ok $d->wire(x=>10, y=>50, X=>30, Y=>70);
     ok $d->wire(x=>70, y=>50, X=>50, Y=>70);
        $d->svg(file=>"svg/freeBoardX");


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
        $d->svg(file=>"svg/freeBoardY");


      is_deeply([$d->freeBoard(x=>33, y=>10, l=>1)], [30,    50, 0, undef]);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲


      is_deeply([$d->freeBoard(x=>5,  y=>10, l=>1)], [ 0,    10, 0, undef]);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲


      is_deeply([$d->freeBoard(x=>75, y=>10, l=>1)], [70, undef, 0, undef]);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲


      is_deeply([$d->freeBoard(x=>40, y=>40, l=>1)], [ 0, undef, 0, undef]);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

   }


=head1 Visualize

Visualize a Silicon chip wiring diagrams

=head2 printWire   ($D, $W)

Print a wire to a string

     Parameter  Description
  1  $D         Drawing
  2  $W         Wire

B<Example:>


  if (1)
   {my  $d = new;
    my $w = $d->wire(x=>3, y=>4, X=>4, Y=>4);
    is_deeply($w, {d =>0, l=>1, x=>3, X=>4, Y=>4, y=>4});
   }


=head2 svg ($D, %options)

Draw the bus lines by level.

     Parameter  Description
  1  $D         Wiring diagram
  2  %options   Options

B<Example:>


  if (1)
   {my  $d = new;
     ok $d->wire(x=>1, y=>1, X=>3, Y=>3, d=>1);
    nok $d->wire(x=>1, y=>2, X=>5, Y=>7, d=>1);                                   # Overlaps previous wire but does not start at the same point
     ok $d->wire(x=>1, y=>1, X=>7, Y=>7, d=>1);

        $d->svg(file=>"svg/overY1");  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

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

=head4 l

Level

=head4 wires

Wires on diagram

=head4 x

Start x position of wire

=head4 y

Start y position of wire



=head1 Private Methods

=head2 overlays($a, $b, $x, $y)

Check whether two segments overlay each other

     Parameter  Description
  1  $a         Start of first segment
  2  $b         End of first segment
  3  $x         Start of second segment
  4  $y         End of second segment

=head2 canLay  ($d, $w, %options)

Confirm we can lay a wire in X and Y with out overlaying an existing wire.

     Parameter  Description
  1  $d         Drawing
  2  $w         Wire
  3  %options   Options

=head2 canLayX ($D, $W, %options)

Confirm we can lay a wire in X with out overlaying an existing wire.

     Parameter  Description
  1  $D         Drawing
  2  $W         Wire
  3  %options   Options

=head2 canLayY ($D, $W, %options)

Confirm we can lay a wire in Y with out overlaying an existing wire.

     Parameter  Description
  1  $D         Drawing
  2  $W         Wire
  3  %options   Options

=head2 svgLevel($D, %options)

Draw the bus lines by level.

     Parameter  Description
  1  $D         Wiring diagram
  2  %options   Options


=head1 Index


1 L<canLay|/canLay> - Confirm we can lay a wire in X and Y with out overlaying an existing wire.

2 L<canLayX|/canLayX> - Confirm we can lay a wire in X with out overlaying an existing wire.

3 L<canLayY|/canLayY> - Confirm we can lay a wire in Y with out overlaying an existing wire.

4 L<freeBoard|/freeBoard> - The free space in +X, -X, +Y, -Y given a point in a level in the diagram.

5 L<length|/length> - Length of a wire including the vertical connections

6 L<levels|/levels> - Number of levels in the diagram

7 L<new|/new> - New wiring diagram.

8 L<numberOfWires|/numberOfWires> - Number of wires in the diagram

9 L<overlays|/overlays> - Check whether two segments overlay each other

10 L<printWire|/printWire> - Print a wire to a string

11 L<startAtSamePoint|/startAtSamePoint> - Whether two wires start at the same point on the same level.

12 L<svg|/svg> - Draw the bus lines by level.

13 L<svgLevel|/svgLevel> - Draw the bus lines by level.

14 L<wire|/wire> - New wire on a wiring diagram.

15 L<wire2|/wire2> - Try connecting two points by going along X first if that fails along Y first to see if a connection can in fact be made.

16 L<wire3c|/wire3c> - Connect two points by moving out from the source to B<s> and from the target to B<t> and then connect source to B<s> to B<t>  to target.

=head1 Installation

This module is written in 100% Pure Perl and, thus, it is easy to read,
comprehend, use, modify and install via B<cpan>:

  sudo cpan install Silicon::Chip::Wiring

=head1 Author

L<philiprbrenan@gmail.com|mailto:philiprbrenan@gmail.com>

L<http://prb.appaapps.com|http://prb.appaapps.com>

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
eval {goto latest} if -e q(/home/phil/);

my sub  ok($)        {!$_[0] and confess; &ok( $_[0])}
my sub nok($)        {&ok(!$_[0])}

# Tests

if (1)
 {my  $d = new;                                                                 #Tlevels
   ok $d->wire(x=>1, y=>1, X=>3, Y=>3);
  nok $d->wire(x=>2, y=>1, X=>5, Y=>5);                                         # X overlaps and does not start at the same point
   ok $d->wire(x=>1, y=>2, X=>7, Y=>7);
      $d->svg(file=>"svg/overX1");
   is_deeply($d->levels, 1);
 }

if (1)
 {my  $d = new;
   ok $d->wire(x=>1, y=>1, X=>3, Y=>5);                                         # First
   ok $d->wire(x=>2, y=>3, X=>4, Y=>5);
  nok $d->wire(x=>2, y=>3, X=>3, Y=>7);                                         # Y overlaps first but did not start at the same point as first
      $d->svg(file=>"svg/overX2");
 }

if (1)                                                                          #Tsvg
 {my  $d = new;
   ok $d->wire(x=>1, y=>1, X=>3, Y=>3, d=>1);
  nok $d->wire(x=>1, y=>2, X=>5, Y=>7, d=>1);                                   # Overlaps previous wire but does not start at the same point
   ok $d->wire(x=>2, y=>1, X=>7, Y=>7, d=>1);
      $d->svg(file=>"svg/overY1");
 }

if (0)                                                                          #TstartAtSamePoint
 {my  $d = new;
   ok (my $a = $d->wire(x=>1, y=>1, X=>5, Y=>3, d=>1));                         # First
   ok (my $b = $d->wire(x=>3, y=>2, X=>5, Y=>4, d=>1));
  nok (my $c = $d->wire(x=>3, y=>2, X=>7, Y=>3, d=>1));                         # X overlaps first but did not start at the same point as first
   ok (my $e = $d->wire(x=>3, y=>2, X=>7, Y=>4, d=>1));
  nok $d->startAtSamePoint($b, $a);
   ok $d->startAtSamePoint($b, $e);
      $d->svg(file=>"svg/overY2");
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
      $d->svg(file=>"svg/square");
 }

if (1)                                                                          #Twire2
 {my  $d = new;
   ok $d->wire (x=>1, y=>1, X=>3, Y=>3);
   ok $d->wire2(x=>1, y=>3, X=>3, Y=>5);

      $d->svg(file=>"svg/wire2");
 }

#latest:;
if (1)                                                                          #Twire #Tnew
 {my $N = 3;
  my  $d = new;
  ok  $d->wire2(x=>$_, y=>1, X=>1+$_, Y=>1+$_) for 1..$N;
  $d->svg(file=>"svg/layers");
  is_deeply($d->levels, 2);
 }

#latest:;
if (1)                                                                          #TfreeBoard
 {my  $d = new;
   ok $d->wire(x=>10, y=>30, X=>30, Y=>10);
   ok $d->wire(x=>70, y=>30, X=>50, Y=>10);
   ok $d->wire(x=>10, y=>50, X=>30, Y=>70);
   ok $d->wire(x=>70, y=>50, X=>50, Y=>70);
      $d->svg(file=>"svg/freeBoardX");

   is_deeply([$d->freeBoard(x=>33, y=>30, l=>1)], [30, 50,     0, undef]);
   is_deeply([$d->freeBoard(x=>30, y=>47, l=>1)], [0,  undef, 30, 50]);
   is_deeply([$d->freeBoard(x=>40, y=>40, l=>1)], [0,  undef,  0, undef]);
 }

#latest:;
if (1)                                                                          #TfreeBoard
 {my  $d = new;
   ok $d->wire(x=>10, y=>30, X=>30, Y=>10, d=>1);
   ok $d->wire(x=>70, y=>30, X=>50, Y=>10, d=>1);
   ok $d->wire(x=>10, y=>50, X=>30, Y=>70, d=>1);
   ok $d->wire(x=>70, y=>50, X=>50, Y=>70, d=>1);
      $d->svg(file=>"svg/freeBoardY");

    is_deeply([$d->freeBoard(x=>33, y=>10, l=>1)], [30,    50, 0, undef]);
    is_deeply([$d->freeBoard(x=>5,  y=>10, l=>1)], [ 0,    10, 0, undef]);
    is_deeply([$d->freeBoard(x=>75, y=>10, l=>1)], [70, undef, 0, undef]);
    is_deeply([$d->freeBoard(x=>40, y=>40, l=>1)], [ 0, undef, 0, undef]);
 }

#latest:;
if (1)
 {nok overlays(4, 8, 2, 3);
   ok overlays(4, 8, 2, 4);
   ok overlays(4, 8, 2, 10);
   ok overlays(4, 8, 6, 10);
  nok overlays(4, 8, 9, 10);
 }

#latest:;
if (1)                                                                          # overlay via wire
 {my  $d = new;
   ok $d->wire(x=>3, y=>0, X=>2, Y=>2, d=>1);
  nok $d->wire(x=>4, y=>0, X=>3, Y=>2, d=>1);
      $d->svg(file=>"svg/ll2");
  is_deeply($d->levels, 1);
 }

#latest:;
if (1)                                                                          #Tlength #TnumberOfWires
 {my  $d = new;
  my $w = $d->wire(x=>1, y=>1, X=>2, Y=>3);
  is_deeply($d->length($w), 5);
  is_deeply($d->numberOfWires, 1);
  nok $d->wire(x=>2, y=>1, X=>2, Y=>3);
  is_deeply($d->numberOfWires, 1);
 }

#latest:;
if (1)                                                                          #TprintWire
 {my  $d = new;
  my $w = $d->wire(x=>3, y=>4, X=>4, Y=>4);
  is_deeply($w, {d =>0, l=>1, x=>3, X=>4, Y=>4, y=>4});
 }

#latest:;
if (1)                                                                          #Twire3c
 {my  $d = new;
  $d->wire(x=>3, y=>4, X=>4, Y=>4);
  $d->wire(x=>3, y=>5, X=>4, Y=>5);
  $d->wire(x=>3, y=>6, X=>4, Y=>6);
  $d->wire(x=>3, y=>7, X=>4, Y=>7);
  $d->wire(x=>3, y=>8, X=>4, Y=>8);
  my $c = $d->wire3c(x=>1, y=>6, X=>6, Y=>7);
  is_deeply($c, [13,
    { d => 1, l => 1, x => 1, X => 6, Y => 9, y => 6 },
    { d => 1, l => 1, x => 6, X => 6, y => 9, Y => 7 },
  ]);

  $d->svg(file=>"svg/wire3c_u");
 }
#  123456789
# 1.........
# 2.xx....xx
# 3.xx....xx
# 4....xx...
# 5.xx....xx
# 6.xx....xx

#latest:;
if (1)                                                                          #Twire3c #TtotalLength
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

  my $c = $d->wire3c(x=>2, y=>4, X=>8, Y=>4);
  is_deeply($c, [13,
     { d => 0, l => 1, X => 4, x => 2, Y => 3, y => 4 },
     { d => 0, l => 1, x => 4, X => 7, y => 3, Y => 3 },
     { d => 1, l => 1, X => 8, x => 7, y => 3, Y => 4 },
  ]);

  is_deeply($d->totalLength, 31);

  $d->svg(file=>"svg/wire3c_n");
 }

&done_testing;
finish: 1
