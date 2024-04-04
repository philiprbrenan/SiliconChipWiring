#!/usr/bin/perl -I/home/phil/perl/cpan/DataTableText/lib/ -I/home/phil/perl/cpan/SvgSimple/lib/  -I/home/phil/perl/cpan/Math-Intersection-Circle-Line/lib
#-------------------------------------------------------------------------------
# Wiring up a silicon chip to transform software into hardware.
# Philip R Brenan at appaapps dot com, Appa Apps Ltd Inc., 2024
#-------------------------------------------------------------------------------
use v5.34;
package Silicon::Chip::Wiring;
our $VERSION = 20240331;
use warnings FATAL => qw(all);
use strict;
use Carp;
use Data::Dump qw(dump);
use Data::Table::Text qw(:all);
use Svg::Simple;
use GDS2;

makeDieConfess;

my $debug = 0;                                                                  # Debug if set
sub debugMask {1}                                                               # Adds a grid to the drawing of a bus line

#D1 Construct                                                                   # Create a Silicon chip wiring diagram on one or more levels as necessary to make the connections requested.

sub new(%)                                                                      # New wiring diagram.
 {my (%options) = @_;                                                           # Options
  genHash(__PACKAGE__,                                                          # Wiring diagram
    %options,                                                                   # Options
    width  => $options{width},                                                  # Width of chip
    height => $options{height},                                                 # Height of chip
    wires  => [],                                                               # Wires on diagram
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
    n => $options{n}//'',                                                       # Optional name
    s => $options{s}//0,                                                        # Start point
    f => $options{f}//0,                                                        # Finish point
   );
  return undef unless defined($options{tested}) or $D->canLay($w, %options);    # Confirm we can lay the wire unless we are controlling placement
  push $D->wires->@*, $w unless defined $options{noplace};                      # Append wire to diagram unless asked not to
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

sub printLevelsAsCode($$%)                                                      # Print the specified levels of the wiring diagram as code so that we can test the interaction of different levels in isolation
 {my ($D, $levels, %options) = @_;                                              # Diagram, levels, options
  my $L = $D->levels;
  my %levels = map {$_=>1} @$levels;
  my @wires = $D->wires->@*;

  my @c;                                                                        # Generated code
  for my $w(@wires)                                                             # Each wire
   {next unless $levels{$w->l};                                                 # Try each existing level
    push @c, sprintf '$D->wire2(x=>%4d, y=>%4d, X=>%4d, Y=>%4d);', @$w{qw(x y X Y)};
   }
  join "\n", @c, '';
 }

sub wire2($%)                                                                   # Try connecting two points by placing wires on one level.
 {my ($D, %options) = @_;                                                       # Diagram, options
  my ($px, $py, $pX, $pY) = @options{qw(x y X Y)};                              # Points to connect
  my $route = $options{route} // '';                                            # Routing methodology
  $px == $pX and $py == $pY and confess "Source == target";                     # Confirm that we are trying to connect separate points

  my $L = $D->levels;                                                           # Levels to try
   ++$L unless $route =~ m(\A(c|d)\Z);                                          # Add new level if necessary and no other routing methodology exists to deal with recalcitrant connections
  for my $l(1..$L)                                                              # Try each existing level
   {for my $d(0..1)
     {my $w = $D->wire(%options, l=>$l, d=>$d, s=>1, f=>1);
      return $w if defined $w;
     }
   }
  $D->wire3c(%options) if $route eq 'c';                                        # Failed to insert the wire on any existing level as an L, so try alternate routing using 2 Ls
  $D->wire3d(%options) if $route eq 'd';                                        # Failed to insert the wire on any existing level as an L, so try alternate routing using 3 Ls
 }

sub wire3c($%)                                                                  # Connect two points through a third point
 {my ($D, %options) = @_;                                                       # Diagram, options
  my ($px, $py, $pX, $pY, $dx, $dy) = @options{qw(x y X Y dx dy)};              # Points to connect
  $px == $pX and $py == $pY and confess "Source == target";                     # Confirm that we are trying to connect separate points

  my $C;                                                                        # The cost of the shortest connecting C wire
  my sub minCost(@)                                                             # Check for lower cost connections
   {my (@w) = @_;                                                               # Wires
    my $c = 0; $c += $D->length($_) for @w;                                     # Sum costs
    $C = [$c, @w] if !defined($C) or $c < $$C[0];                               # Lower cost connection?
   }

  my $levels = $D->levels;                                                      # Levels

  for my $l(1..$levels)                                                         # Each level
   {my $x1 = 0;                                                                 # Jump point search start in x
    my $y1 = 0;                                                                 # Jump point search start in y
    my $x2 = $D->width;                                                         # Jump point search end   in x
    my $y2 = $D->height;                                                        # Jump point search end   in y
    for     my $x($x1..$x2)                                                     # Jump placements in x
     {for   my $y($y1..$y2)                                                     # Source jump placements in y
       {for my $d(0..1)                                                         # Direction
         {next if $x == $px and $y == $py;                                      # Avoid using the source or target as the jump point
          next if $x == $pX and $y == $pY;
          my $s = $D->wire(x=>$px, y=>$py, X=>$x, Y=>$y, l=>$l, d=>$d, noplace=>1); # Can we reach the jump point from the source?
          next unless defined $s;
          my $t = $D->wire(X=>$pX, Y=>$pY, x=>$x, y=>$y, l=>$l, d=>$d, noplace=>1); # Can we reach the jump point from the target?
          next unless defined $t;
          minCost($s, $t);                                                      # Lower cost?
         }
       }
     }
   }

  return $C if defined $options{noplace};                                       # Do not place the wire on the diagram
  return $D->wire(%options, l=>$levels+1) unless defined $C;                    # No connection possible on any existing level, so start a new level and connect there

  if ($C)                                                                       # Create the wires
   {my @C = @$C; shift @C;
    $C[0]->s = 1; $C[-1]->f = 1;                                                # Mark the start and end of the wires
    for my $i(keys @C)
     {my $c = $C[$i];
      my $w = $D->wire(%$c);                                                    # Join the wires
     }
   }
  $C
 }

sub radiateOut($$$$$%)                                                          # Radiate out around a point
 {my ($D, $px, $py, $lx, $ly, %options) = @_;                                   # Diagram, start point x , start point y, limit in x, limit in y, options
  my $width  = $D->width;                                                       # Width of diagram if known
  my $height = $D->height;                                                      # Height of diagram if known

  my @p;
  for   my $x($px-$lx..$px+$lx)
   {for my $y($py-$ly..$py+$ly)
     {next if $x == $px and $y == $py;                                          # Skip start point
      next if $x < 0 or $y < 0;
      next if $width  and $x > $width;
      next if $height and $y > $height;
      push @p, [$x, $y, abs($px - $x) + abs($py - $y)];
     }
   }
  sort {$$a[2] <=> $$b[2]} @p;                                                  # Points ordered by distance from start point
 }

sub wire3d($%)                                                                  # Connect two points by moving out from the source to B<s> and from the target to B<t> and then connect source to B<s> to B<t>  to target.
 {my ($D, %options) = @_;                                                       # Diagram, options
  my ($px, $py, $pX, $pY, $name, $debug) = @options{qw(x y X Y n debug)};       # Points to connect
  my $dx = $options{searchDx} // 1;                                             # Radius to consider in x when searching for jump points
  my $dy = $options{searchDy} // 1;                                             # Radius to consider in y  when searching for jump points
  $px == $pX and $py == $pY and confess "Source == target";                     # Confirm that we are trying to connect separate points

  my $C = genHash(__PACKAGE__."::CompositeWireL",                               # The cost of the shortest connecting C wire
    diagram => $D,                                                              # Diagram on which we are drawing
    cost    => undef,                                                           # Cost of the connection
    wires   => [],                                                              # L shaped wires in connection
  );

  my sub minCost(@)                                                             # Check for lower cost connections
   {my (@w) = @_;                                                               # Wires
    my $c = 0; $c += $D->length($_) for @w;                                     # Sum costs
    if (!defined($C->cost) or $c < $C->cost)                                    # Lower cost connection?
     {$C->cost  = $c;
      $C->wires = [@w];
     }
   }

  my sub cheaper($$$$)                                                          # Worth continuing with a wire because it is shorter than the current cost
   {!defined($C->cost) or  &distance(@_) < $C->cost;                            # Potentially lower cost connection?
   }

  my $levels = $D->levels;                                                      # Levels

  my %routes;                                                                   # Test wires cache

  my sub route($$$$$)                                                           # Test a wire
   {my ($x, $y, $X, $Y, $l, $d) = @_;                                           # Start x, start y, end x, end y, level
    return undef unless cheaper($x, $y, $X, $Y);                                # Worth continuing with a wire because it is shorter than the current cost
    for my $d(0..1)                                                             # Each possible direction
     {my $s = "$x $y $X $Y $l $d";                                              # Cache key
      return $routes{$s} if exists $routes{$s};                                 # Do we know the result for this wire?

      my $w = $D->wire(x=>$x, y=>$y, X=>$X, Y=>$Y, l=>$l, d=>$d,                # Can we reach the source jump point from the source?
        ($name ? (n => $name) : ()), noplace=>1);
      return $routes{$s} = $w if $w;                                            # Wire could be routed
     }
    undef                                                                       # Cannot route a wire between these two points using an L
   };


  for my $l(1..$levels)                                                         # Can we reach the target directly from the source on any level
   {if (my $w = route($px, $py, $pX, $pY, $l))                                  # Can we reach the source jump point from the source on this level?
     {minCost($w);                                                              # Cost of the connection
     }
   }
  return $C if defined $C->cost;                                                # No other connection could be better than a direct connection

  my @s = $D->radiateOut($px, $py, $dx, $dy);                                   # X radius
  my @t = $D->radiateOut($pX, $pY, $dx, $dy);                                   # Y radius

  for my $s(@s)                                                                 # Source jump placements
   {my ($sx, $sy) = @$s;
    next if $sx == $px and $sy == $py;                                          # Avoid using the source or target as the jump point
    next if $sx == $pX and $sy == $pY;
    for my $ls(1..$levels)                                                      # Source level
     {my $sw = route($px, $py, $sx, $sy, $ls);                                  # Can we reach the source jump point from the source?
      next unless defined $sw;
      if (my $w = route($sx, $sy, $pX, $pY, $ls))                               # Can we reach the source jump point from the target?
       {minCost($sw, $w);                                                       # Cost of the connection
       }

      for my $t(@t)                                                             # Target jump placements
       {my ($tx, $ty) = @$t;
        next if $tx == $px and $ty == $py;                                      # Avoid using the source or target as the jump point
        next if $tx == $pX and $ty == $pY;

        for my $lt(1..$levels)                                                  # Target level
         {my $tw = route($tx, $ty, $pX, $pY, $lt);                              # Can we reach the target jump point from the target
          next unless defined $tw;
          if (my $w = route($px, $py, $tx, $ty, $lt))                           # Can we reach the target jump point from the source?
           {minCost($w, $tw);                                                   # Cost of the connection
           }


          if ($sx == $tx and $sy == $ty)                                        # Identical jump points
           {minCost($sw, $tw);                                                  # Lower cost?
           }
          elsif (my $Sw = route($px, $py, $tx, $ty, $lt))                       # Can we reach the target jump point directly from the source
           {minCost($Sw, $tw);                                                  # Lower cost?
           }
          elsif (my $Tw = route($sx, $sy, $pX, $pY, $lt))                       # Can we reach the target  directly from the source jump point
           {minCost($sw, $Tw);                                                  # Lower cost?
           }
          else                                                                  # Differing jump points
           {for my $ll(1..$levels)                                              # Level for middle wire
             {if (my $stw = route($sx, $sy, $tx, $ty, $ll))                     # Can we reach the target jump point from the source jump point
               {minCost($sw, $stw, $tw);                                        # Lower cost?
               }
             }
           }
         }
       }
     }
   }

  return $C if defined $options{noplace};                                       # Do not place the wire on the diagram
  minCost($D->wire(%options, l=>$levels+1)) unless defined $C->cost;            # No connection possible on any existing level, so start a new level and connect there

  my @w = $C->wires->@*;
  $w[0]->s = 1; $w[-1]->f = 1;                                                # Mark start and end of composite wire
  for my $w(@w)
   {$D->wire(%$w, tested=>1);
   }
  $C
 }

sub startAtSamePoint($$$)                                                       # Whether two wires start at the same point on the same level.
 {my ($D, $a, $b) = @_;                                                         # Drawing, wire, wire
  my ($x, $y, $l) = @$a{qw(x y l)};
  my ($X, $Y, $L) = @$b{qw(x y l)};
  $l == $L and $x == $X and $y == $Y                                            # True if they start at the same point
 }

sub distance($$$$)                                                              # Manhattan distance between two points
 {my ($x, $y, $X, $Y) = @_;                                                     # Start x, start y, end x, end y
  abs($X - $x) + abs($Y - $y)
 }

sub length($$)                                                                  # Length of a wire including the vertical connections
 {my ($D, $w) = @_;                                                             # Drawing, wire
  my ($x, $y, $X, $Y) = @$w{qw(x y X Y)};
  my $dx = abs($X - $x); my $dy = abs($Y - $y);
  return 1 + $dx unless $dy;  # Dubious - why is there a vertical connection here?
  return 1 + $dy unless $dx;  # Ditto
  2 + $dx + $dy               # Why 2 ?
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

sub findShortestPath($$$$)                                                      # Find the shortest path between two points in a two dimensional image stepping only from/to adjacent marked cells. The permissible steps are given in two imahes, one for x steps and one for y steps.
 {my ($imageX, $imageY, $start, $finish) = @_;                                  # ImageX{x}{y}, ImageY{x}{y}, start point, finish point
  my %ix = %$imageX; my %iy = %$imageY;                                         # Shorten names

  my ($x, $y) = @$start;                                                        # Start point
  my ($X, $Y) = @$finish;                                                       # Finish point

  $ix{$x}{$y} or $iy{$x}{$y} or confess <<"END" =~ s/\n(.)/ $1/gsr;             # Check start point is accessible
Start point [$x, $y] is not in a selected cell
END
  $ix{$X}{$Y} or $iy{$X}{$Y} or confess <<"END" =~ s/\n(.)/ $1/gsr;             # Check finish point is accessible
End point [$X, $Y] is not in a selected cell
END

  my %o; $o   {$x}{$y} = 1;                                                     # Cells at current edge of search
  my %b; $b   {$x}{$y} = 1;                                                     # Shortest path to this cell from start via breadth first search
  my %d; $d{1}{$x}{$y} = 1;                                                     # Cells at depth from start

  for my $d(2..1e6)                                                             # Depth of search
   {last unless keys %o;                                                        # Keep going until we cannot go any further
    my %n;                                                                      # Cells at new edge of search
    for   my $x(sort keys %o)                                                   # Current frontier x
     {for my $y(sort keys $o{$x}->%*)                                           # Current frontier y
       {my sub search($$$)                                                      # Search from a point in the current frontier
         {my ($i, $x, $y) = @_;                                                 # Point to test
          if ($$i{$x}{$y} and !exists $b{$x}{$y})                               # Located a new unclassified cell
           {$d{$d}{$x}{$y} = $n{$x}{$y} = $b{$x}{$y} = $d;                      # Set depth for cell and record is as being at that depth
           }
         }
        search(\%ix, $x-1, $y);   search(\%ix, $x+1, $y);                       # Search for a step in x
        search(\%iy, $x,   $y-1); search(\%iy, $x,   $y+1);                     # Search for a step in y
       }
     }
    %o = %n;                                                                    # The new frontier becomes the settled fontoer
   }

  return () unless my $N = $b{$X}{$Y};                                          # Return empty list if there is no path from the start to the finish

  my @p = [$X, $Y];                                                             # Shortest path
  if (1)                                                                        # Find a shortest path
   {my ($x, $y, $d) = ($X, $Y, $N);                                             # Work back from end point
    for my $d(reverse 1..$N-1)                                                  # Work backwards
     {push @p, [($x, $y, undef) =                                                      # Search for the link in the path back to the start
        $d{$d}{$x-1}{$y} ? ($x-1, $y, 0) :
        $d{$d}{$x+1}{$y} ? ($x+1, $y, 0) :
        $d{$d}{$x}{$y-1} ? ($x, $y-1, 1) : ($x, $y+1, 1)];
     }
   }
  reverse @p                                                                    # Reverse backweards path otr get Path from start to finish
 }

#D1 Visualize                                                                   # Visualize a Silicon chip wiring diagrams

my sub wireHeader()                                                             #P Wire header
 {"   x,   y  S      X,   Y  F   L  d  Name";
 }

sub print($%)                                                                   # Print a diagram
 {my ($d, %options) = @_;                                                       # Drawing, options
  my @t; my $l = 0;
  push @t, wireHeader;
  for my $w($d->wires->@*)
   {push @t, $d->printWire($w);
    $l += $d->length($w);
   }
  unshift @t, "Length: $l";
  join "\n", @t, ''
 }

sub printWire($$)                                                               # Print a wire to a string
 {my ($D, $W) = @_;                                                             # Drawing, wire
  my ($x, $y, $X, $Y, $l, $d, $n, $s, $f) = @$W{qw(x y X Y l d n s f)};
  sprintf "%4d,%4d,%2d   %4d,%4d,%2d  %2d  %d".($n ? "  $n": ""), $x, $y, $s, $X, $Y, $f, $l, $d
 }

sub Silicon::Chip::Wiring::CompositeWireL::print($%)                            # Print a composite wire
 {my ($cc, %options) = @_;                                                      # Composite connection, options
  my @t = "Cost: ".($cc->cost//'?')."\n".wireHeader;
  for my $w($cc->wires->@*)
   {push @t, printWire($cc->diagram, $w);
   }
  join "\n", @t, '';
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

  my $t = $svg->print(width=>$D->width, height=>$D->height);                          # Text of svg

  if (my $f = $options{file})                                                   # Optionally write to an svg file
   {confess "Wiring file already exists: $f\n" if -e $f;
    owf(fpe(q(svg), $f, q(svg)), $t)
   }

  $t
 }

sub gds2($%)                                                                    # Draw the wires using GDS2
 {my ($wiring, %options) = @_;                                                  # Wiring diagram, options
  my $delta     = 1/4;                                                          # Offset from edge of each gate cell
  my $wireWidth = 1/4;                                                          # Width of a wire

  confess "gdsOut required" unless my $outGds = $options{outGds};               # Output file required
  my $outFile = createEmptyFile(fpe qw(gds), $outGds, qw(gds));                 # Create output file to make any folders needed

  my $g = new GDS2(-fileName=>">$outFile");                                     # Draw as Graphics Design System 2
  $g->printInitLib(-name=>$outGds);
  $g->printBgnstr (-name=>$outGds);

  my $s  = $wireWidth/2;                                                        # Half width of the wore
  my $t  = 1/2 + $s;                                                            # Center of wire
  my $S  = $wireWidth; # 2 * $s                                                 # Width of wire
  my @w  = $wiring->wires->@*;                                                  # Wires
  my $wL = 4;                                                                   # Wiring layers within each level

  my $levels    = 0;                                                            # Levels
  my $width     = 0;                                                            # Width
  my $height    = 0;                                                            # Height

  for my $w(@w)                                                                 # Size of diagram
   {$levels = maximum($$w{l}, $levels);
    $width  = maximum(@$w{qw(x X)}, $width);
    $height = maximum(@$w{qw(y Y)}, $height);
   }

  for my $wl(1..$levels)                                                        # Vias
   {for my $l(0..$wl-1)                                                         # Insulation, x layer, insulation, y layer
     {for   my $x(0..$width)                                                    # Gate io pins run vertically along the "vias"
       {for my $y(0..$height)
         {my $x1 = $x; my $y1 = $y;
          my $x2 = $x1 + $wireWidth; my $y2 = $y1 + $wireWidth;
          $g->printBoundary(-layer=>$wl*$wL+$l, -xy=>[$x1,$y1, $x2,$y1, $x2,$y2, $x1,$y2]); # Via
         }
       }
     }
   }

  for my $x(0..$width)                                                          # Number cells
   {$g->printText(-xy=>[$x, -1/8], -string=>"$x", -font=>3);                    # X coordinate
   }

  for my $y(1..$height)                                                         # Number cells
   {$g->printText(-xy=>[0, $y+$wireWidth*1.2], -string=>"$y", -font=>3);        # Y coordinate
   }

  my sub via($$$)                                                               # Draw a vertical connector
   {my ($x, $y, $l) = @_;                                                       # Options
    $g->printBoundary(-layer=>$l*$wL+2, -xy=>[$x-$s,$y-$s, $x+$s,$y-$s, $x+$s,$y+$s, $x-$s,$y+$s]); # Vertical connector
   }

  say STDERR wireHeader;
  for my $w(@w)                                                                 # Layout each wire
   {my ($x, $y, $X, $Y, $d, $l, $start, $finish) = @$w{qw(x y X Y d l s f)};
    say STDERR $wiring->printWire($w);

    my sub nx {$x < $X ? -$s : +$s}
    my sub ny {$y < $Y ? -$s : +$s}

    my @s = $d == 0 ?                                                           # Segment drawing order
      ([[$x+$t, $y+$t], [$X+$t, $y+$t]],
       [[$X+$t, $y+$t], [$X+$t, $Y+$t]]):
      ([[$x+$t, $y+$t], [$x+$t, $Y+$t]],
       [[$x+$t, $Y+$t], [$X+$t, $Y+$t]]);

    if ($start)                                                                 # Connect to start
     {$s[0][1][0] += $s;
      unshift $s[0]->@*, [$x+$s, $y+$S], [$x+$s, $y+$t];
     }
    if ($finish)                                                                # Connect to start
     {$s[1][0][1] += $s;
      push    $s[1]->@*, [$X+$s, $Y+$t], [$X+$s, $Y+$S];
     }

    my sub dedupe($)                                                            # Dedupe an array of coordinates
     {my ($A) = @_;                                                             # Array iof coordinate pairs
      my %s;
      my @A;
      for my $a(@$A)
       {my $k = join ',', @$a;
        if ($s{$k}++) {} else {push @A, @$a}
       }
      @A > 3 ? [@A] : undef                                                     # Need at least 4 coordinates to draw a line
     }

    $s[$_] = dedupe($s[$_]) for keys @s;                                        # Dedupe each array of wire path coordinates

say STDERR "LLLL ", dump(\@s);
    $g->printPath(-layer=>$wL*$l+1, -width=>$S, -xy => $s[0]) if $s[0];
    $g->printPath(-layer=>$wL*$l+3, -width=>$S, -xy => $s[1]) if $s[1];
   }

  $g->printEndstr;
  $g->printEndlib();                                                            # Close the library
 }

sub gds2_2222($%)                                                                    # Draw the wires using GDS2
 {my ($wiring, %options) = @_;                                                  # Wiring diagram, options
  my $delta     = 1/4;                                                          # Offset from edge of each gate cell
  my $wireWidth = 1/4;                                                          # Width of a wire

  confess "gdsOut required" unless my $outGds = $options{outGds};               # Output file required
  my $outFile = createEmptyFile(fpe qw(gds), $outGds, qw(gds));                 # Create output file to make any folders needed

  my $g = new GDS2(-fileName=>">$outFile");                                     # Draw as Graphics Design System 2
  $g->printInitLib(-name=>$outGds);
  $g->printBgnstr (-name=>$outGds);

  my $s  = $wireWidth/2;                                                        # Half width of the wore
  my $t  = 1/2 + $s;                                                            # Center of wire
  my $S  = $wireWidth; # 2 * $s                                                 # Width of wire
  my @w  = $wiring->wires->@*;                                                  # Wires
  my $wL = 4;                                                                   # Wiring layers within each level

  my $levels    = 0;                                                            # Levels
  my $width     = 0;                                                            # Width
  my $height    = 0;                                                            # Height
  for my $w(@w)                                                                 # Layout each wire
   {$levels = maximum($$w{l}, $levels);
    $width  = maximum(@$w{qw(x X)}, $width);
    $height = maximum(@$w{qw(y Y)}, $height);
   }

  for my $wl(1..$levels)                                                        # Vias
   {for my $l(0..$wl-1)                                                         # Insulation, x layer, insulation, y layer
     {for   my $x(0..$width)                                                    # Gate io pins run vertically along the "vias"
       {for my $y(0..$height)
         {my $x1 = $x; my $y1 = $y;
          my $x2 = $x1 + $wireWidth; my $y2 = $y1 + $wireWidth;
          $g->printBoundary(-layer=>$wl*$wL+$l, -xy=>[$x1,$y1, $x2,$y1, $x2,$y2, $x1,$y2]); # Via
         }
       }
     }
   }

  for my $x(0..$width)                                                          # Number cells
   {$g->printText(-xy=>[$x, -1/8], -string=>"$x", -font=>3);                    # X coordinate
   }

  for my $y(1..$height)                                                         # Number cells
   {$g->printText(-xy=>[0, $y+$wireWidth*1.2], -string=>"$y", -font=>3);        # Y coordinate
   }

  my sub dd($$$$%)                                                              # Draw a line incrementally
   {my ($x, $y, $X, $Y, @move) = @_;                                            # Start, end, moves
    my @p;                                                                      # Points
    for my $i(keys @move)
     {my $m = $move[$i];
      if (!defined $m)                                                          # Undefined reuses the last value
       {push @p, $p[-2];
       }
      elsif (ref($m) =~ m(\Aarray\Z)i)                                          # An array marks an absolute position
       {push @p, @$m;
       }
      elsif (ref($m) =~ m(\Ascalar\Z)i)                                         # A reference marks a position relative to the end
       {push @p, ($i % 2 == 0 ? $X : $Y) + $$m;
       }
      else                                                                      # Anything else is relative to the start
       {push @p, ($i % 2 == 0 ? $x : $y) + $m;
       }
     }
    (-width=>$S, -xy=>[@p])
   }

  say STDERR "WWWW ", wireHeader;
  for my $w(@w)                                                                 # Layout each wire
   {my ($x, $y, $X, $Y, $d, $l, $start, $finish) = @$w{qw(x y X Y d l s f)};
    say STDERR "WWWW ", $wiring->printWire($w);
#my $debug = $x == 1 && $y == 4;
#say STDERR "AAAA ", dump($x, $y, $X, $Y, "start=", $start, $finish);
#say STDERR "AAAA ", dump() if $debug;

    if ($start and $finish)
     {if (abs($X-$x) == 1 && $y == $Y)                                          #sfa Adjacent in x
       {my ($x, $y, $X, $Y) = $x < $X ? ($x, $y, $X, $Y) : ($X, $Y, $x, $y);
        $g->printPath(-layer=>$wL*$l+1, dd $x,$y,$X,$Y, $S, $s, \0, \$s);
        next;
       }

      if (abs($Y-$y) == 1 && $x == $X)                                          #sfa Adjacent in y
       {my ($x, $y, $X, $Y) = $y < $Y ? ($x, $y, $X, $Y) : ($X, $Y, $x, $y);
        $g->printPath(-layer=>$wL*$l+1, dd $x,$y,$X,$Y, $s, $S, \$s, \0);
        next;
       }

      if ($X == $x)                                                             #sfb Same column
       {my ($x, $y, $X, $Y) = $y < $Y ? ($x, $y, $X, $Y) : ($X, $Y, $x, $y);
        $g->printPath(-layer=>$wL*$l+1, dd $x,$y,$X,$Y,  $S, $s,  $t, undef, undef, \$s, \$S, undef);
        next;
       }

      if ($Y == $y)                                                             #sfb Same row
       {my ($x, $y, $X, $Y) = $y < $Y ? ($x, $y, $X, $Y) : ($X, $Y, $x, $y);
        $g->printPath(-layer=>$wL*$l+1, dd $x,$y,$X,$Y,  $s, $S,  undef, $t, \$s, \$t, \$s, \$S);
        next;
       }

      if ($d == 0 and $Y == $y + 1)                                             #sfc First X, then up 1
       {say STDERR "AAAA";
        my ($x, $y, $X, $Y) = $y < $Y ? ($x, $y, $X, $Y) : ($X, $Y, $x, $y);
        $g->printPath(-layer=>$wL*$l+1, dd $x,$y,$X,$Y, $s, $S, undef, $t, \$s, undef, \$s, \0);
        next;
       }

      if ($d == 1 and $X == $x + 1 and $y < $Y)                                 #sfc First Y then right 1
       {my ($x, $y, $X, $Y) = $y < $Y ? ($x, $y, $X, $Y) : ($X, $Y, $x, $y);
        $g->printPath(-layer=>$wL*$l+1, dd $x,$y,$X,$Y, $S, $s, $t, undef, undef, \$s, \$s, \$s);
        next;
       }

      if ($d == 0)                                                              #sfd X first
       {$g->printPath(-layer=>$wL*$l+1, -width=>$S, -xy=>[                      # Along x
          $x+$s,      $y+$S,
          $x+$s,      $y+$t,
          $X+1-$S,   $y+$t]);
        $g->printBoundary(-layer=>$wL*$l+2, -xy=>[                              # Up one level
          $X+1/2,     $y+1/2,
          $X+1/2+$S, $y+1/2,
          $X+1/2+$S, $y+1/2+$S,
          $X+1/2,     $y+1/2+$S]);                                              # Along y
        $g->printPath(-layer=>$wL*$l+3, -width=>$S, -xy=>[
          $X+1/2+$s,  $y+1/2+$S,
          $X+1/2+$s,  $Y+$s,
          $X,         $Y+$s]);
       }
      else                                                                      # Y first
       {$g->printPath(-layer=>$wL*$l+1, -width=>$S, -xy=>[                      # Along x
          $X+$s,      $Y+$S,
          $X+$s,      $Y+$t,
          $x+1-$S,   $Y+$t]);
        $g->printBoundary(-layer=>$wL*$l+2, -xy=>[                              # Up one level
          $x+1/2,     $Y+1/2+$S,
          $x+1/2+$S, $Y+1/2+$S,
          $x+1/2+$S, $Y+1/2,
          $x+1/2,     $Y+1/2,
          ]);
        $g->printPath(-layer=>$wL*$l+3, -width=>$S, -xy=>[                      # Along y
          $x+$S,     $y+$s,
          $x+1/2+$s,  $y+$s,
          $x+1/2+$s,  $Y+1/2+$S,
          ]);
       }
     }
    elsif ($start)
     {if (abs($X-$x) == 1 and $y == $Y)                                         # Adjacent in x
       {my ($x1, $y1, $x2, $y2) = $x < $X ? ($x, $y, $X, $Y) : ($X, $Y, $x, $y);
        $g->printPath(-layer=>$wL*$l+1, -width=>$S, -xy=>[$x+$S,  $y+$s, $X, $Y+$s]);
        next;
       }

      if ($X == $x)                                                             # Same column
       {my ($x1, $y1, $x2, $y2) = $y < $Y ? ($x, $y, $X, $Y) : ($X, $Y, $x, $y);
        $g->printPath(-layer=>$wL*$l+1, -width=>$S, -xy=>[$x+$S, $y+$s,  $x+1/2+$s, $y+$s,  $X+1/2+$s, $Y+$s, $X+$S, $Y+$s]);
        next;
       }

      if ($Y == $y)                                                             # Same row
       {my ($x1, $y1, $x2, $y2) = $x < $X ? ($x, $y, $X, $Y) : ($X, $Y, $x, $y);
        $g->printPath(-layer=>$wL*$l+1, -width=>$S, -xy=>[$x+$s, $y+$S, $x+$s, $y+1/2+$s, $X+$s, $Y+1/2+$s, $X+$s, $Y+$S]);
        next;
       }

      if ($d == 0 and $Y == $y + 1 and $x < $X)                                 # Going right and then up 1
       {$g->printPath(-layer=>$wL*$l+1, -width=>$S, -xy=>[$x+$s, $y+$S, $x+$s, $y+1/2+$s, $X+$s, $y+1/2+$s, $X+$s, $Y]);
        next;
       }

      if ($d == 1 and $X == $x + 1 and $y < $Y)                                 # Going up then right 1
       {$g->printPath(-layer=>$wL*$l+1, -width=>$S, -xy=>[$x+$S, $y+$s, $x+1/2+$S, $y+$s, $x+1/2+$S, $Y+$s, $X, $Y+$s]);
        next;
       }

      if (abs($Y-$y) == 1 and $x == $X)                                         # Adjacent in y
       {my ($x1, $y1, $x2, $y2) = $y < $Y ? ($x, $y, $X, $Y) : ($X, $Y, $x, $y);
        $g->printPath(-layer=>$wL*$l+1, -width=>$S, -xy=>[$x+$s, $y+$S, $x+$s, $Y]);
        next;
       }

      if ($d == 0)                                                              # X first
       {$g->printPath(-layer=>$wL*$l+1, -width=>$S, -xy=>[                     # Along x
          $x+$s,      $y+$S,
          $x+$s,      $y+$t,
          $X+1-$S,   $y+$t]);
        $g->printBoundary(-layer=>$wL*$l+2, -xy=>[                              # Up one level
          $X+1/2,     $y+1/2,
          $X+1/2+$S, $y+1/2,
          $X+1/2+$S, $y+1/2+$S,
          $X+1/2,     $y+1/2+$S]);                                             # Along y
        $g->printPath(-layer=>$wL*$l+3, -width=>$S, -xy=>[
          $X+1/2+$s,  $y+1/2+$S,
          $X+1/2+$s,  $Y+$s,
          $X,         $Y+$s]);
       }
      else                                                                      # Y first
       {$g->printPath(-layer=>$wL*$l+1, -width=>$S, -xy=>[                     # Along x
          $X+$s,      $Y+$S,
          $X+$s,      $Y+$t,
          $x+1-$S,   $Y+$t]);
        $g->printBoundary(-layer=>$wL*$l+2, -xy=>[                              # Up one level
          $x+1/2,     $Y+1/2+$S,
          $x+1/2+$S, $Y+1/2+$S,
          $x+1/2+$S, $Y+1/2,
          $x+1/2,     $Y+1/2,
          ]);
        $g->printPath(-layer=>$wL*$l+3, -width=>$S, -xy=>[                     # Along y
          $x+$S,     $y+$s,
          $x+1/2+$s,  $y+$s,
          $x+1/2+$s,  $Y+1/2+$S,
          ]);
       }
     }
    elsif ($finish)
     {if (abs($X-$x) == 1 and $y == $Y)                                         # Adjacent in x
       {my ($x1, $y1, $x2, $y2) = $x < $X ? ($x, $y, $X, $Y) : ($X, $Y, $x, $y);
        $g->printPath(-layer=>$wL*$l+1, -width=>$S, -xy=>[$x+$S,  $y+$s, $X, $Y+$s]);
        next;
       }

      if ($X == $x)                                                             # Same column
       {my ($x1, $y1, $x2, $y2) = $y < $Y ? ($x, $y, $X, $Y) : ($X, $Y, $x, $y);
        $g->printPath(-layer=>$wL*$l+1, -width=>$S, -xy=>[$x+$S, $y+$s,  $x+1/2+$s, $y+$s,  $X+1/2+$s, $Y+$s, $X+$S, $Y+$s]);
        next;
       }

      if ($Y == $y)                                                             # Same row
       {my ($x1, $y1, $x2, $y2) = $x < $X ? ($x, $y, $X, $Y) : ($X, $Y, $x, $y);
        $g->printPath(-layer=>$wL*$l+1, -width=>$S, -xy=>[$x+$s, $y+$S, $x+$s, $y+1/2+$s, $X+$s, $Y+1/2+$s, $X+$s, $Y+$S]);
        next;
       }

      if ($d == 0 and $Y == $y + 1 and $x < $X)                                 # Going right and then up 1
       {$g->printPath(-layer=>$wL*$l+1, -width=>$S, -xy=>[$x+$s, $y+$S, $x+$s, $y+1/2+$s, $X+$s, $y+1/2+$s, $X+$s, $Y]);
        next;
       }

      if ($d == 1 and $X == $x + 1 and $y < $Y)                                 # Going up then right 1
       {$g->printPath(-layer=>$wL*$l+1, -width=>$S, -xy=>[$x+$S, $y+$s, $x+1/2+$S, $y+$s, $x+1/2+$S, $Y+$s, $X, $Y+$s]);
        next;
       }

      if (abs($Y-$y) == 1 and $x == $X)                                         # Adjacent in y
       {my ($x1, $y1, $x2, $y2) = $y < $Y ? ($x, $y, $X, $Y) : ($X, $Y, $x, $y);
        $g->printPath(-layer=>$wL*$l+1, -width=>$S, -xy=>[$x+$s, $y+$S, $x+$s, $Y]);
        next;
       }

      if ($d == 0)                                                              # X first
       {$g->printPath(-layer=>$wL*$l+1, -width=>$S, -xy=>[                     # Along x
          $x+$s,      $y+$S,
          $x+$s,      $y+$t,
          $X+1-$S,   $y+$t]);
        $g->printBoundary(-layer=>$wL*$l+2, -xy=>[                              # Up one level
          $X+1/2,     $y+1/2,
          $X+1/2+$S, $y+1/2,
          $X+1/2+$S, $y+1/2+$S,
          $X+1/2,     $y+1/2+$S]);                                             # Along y
        $g->printPath(-layer=>$wL*$l+3, -width=>$S, -xy=>[
          $X+1/2+$s,  $y+1/2+$S,
          $X+1/2+$s,  $Y+$s,
          $X,         $Y+$s]);
       }
      else                                                                      # Y first
       {$g->printPath(-layer=>$wL*$l+1, -width=>$S, -xy=>[                     # Along x
          $X+$s,      $Y+$S,
          $X+$s,      $Y+$t,
          $x+1-$S,   $Y+$t]);
        $g->printBoundary(-layer=>$wL*$l+2, -xy=>[                              # Up one level
          $x+1/2,     $Y+1/2+$S,
          $x+1/2+$S, $Y+1/2+$S,
          $x+1/2+$S, $Y+1/2,
          $x+1/2,     $Y+1/2,
          ]);
        $g->printPath(-layer=>$wL*$l+3, -width=>$S, -xy=>[                     # Along y
          $x+$S,     $y+$s,
          $x+1/2+$s,  $y+$s,
          $x+1/2+$s,  $Y+1/2+$S,
          ]);
       }
     }
   }

  $g->printEndstr;
  $g->printEndlib();                                                            # Close the library
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

=head2 Assumptions

The gates are on the bottom layer if the chip.  Above the gates layer there as
many wiring levels as are needed to connect the gates. Vertical vias run from
the pins of the gates to each layer, so each vertical via can connect to an
input pin or an output pin of a gate.  On each level some of the vias (hence
gate pins) are connected together by L shaped strips of metal conductor running
along X and Y. The Y strips can cross over the X strips.  Each gate input pin
is connect to no more than one gate output pin.  Each gate output pin is
connected to no more than one gate input pin.  L<Silicon::Chip> automatically
inserts fan outs to enforce this rule. The fan outs look like sea shells on the
gate layout diagrams.

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
        $d->svg(file=>"square");
   }

  if (1)
   {my $N = 3;

    my  $d = new;  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

    ok  $d->wire2(x=>$_, y=>1, X=>1+$_, Y=>1+$_) for 1..$N;
    $d->svg(file=>"layers");
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

        $d->svg(file=>"square");
   }

  if (1)
   {my $N = 3;
    my  $d = new;
    ok  $d->wire2(x=>$_, y=>1, X=>1+$_, Y=>1+$_) for 1..$N;
    $d->svg(file=>"layers");
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



        $d->svg(file=>"wire2");  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

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

        $d->svg(file=>"overY2");
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
      $d->svg(file=>"overX1");
   is_deeply($d->levels, 1);
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
   ok $d->wire(x=>2, y=>1, X=>7, Y=>7, d=>1);
      $d->svg(file=>"overY1");
 }

if (0)                                                                          #TstartAtSamePoint
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
  my  $d = new(width=>$N+1, height=>$N+1) ;
  ok  $d->wire2(x=>$_, y=>1, X=>1+$_, Y=>1+$_) for 1..$N;
  $d->svg(file=>"layers");
  is_deeply($d->levels, 2);
 }

#latest:;
if (1)                                                                          #TfreeBoard
 {my  $d = new;
   ok $d->wire(x=>10, y=>30, X=>30, Y=>10);
   ok $d->wire(x=>70, y=>30, X=>50, Y=>10);
   ok $d->wire(x=>10, y=>50, X=>30, Y=>70);
   ok $d->wire(x=>70, y=>50, X=>50, Y=>70);
      $d->svg(file=>"freeBoardX");

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
      $d->svg(file=>"freeBoardY");

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
      $d->svg(file=>"ll2");
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
  is_deeply($w, {d =>0, l=>1, x=>3, X=>4, Y=>4, y=>4, n=>'', s=>0, f=>0});
 }

#latest:;
if (1)                                                                          #Twire3d
 {my  $d = new;
  $d->wire(x=>3, y=>4, X=>4, Y=>4);
  $d->wire(x=>3, y=>5, X=>4, Y=>5);
  $d->wire(x=>3, y=>6, X=>4, Y=>6);
  $d->wire(x=>3, y=>7, X=>4, Y=>7);
  $d->wire(x=>3, y=>8, X=>4, Y=>8);
  my $c = $d->wire3d(x=>1, y=>6, X=>6, Y=>7, searchDx=>1, searchDy=>2);

  is_deeply($c->print, <<END);
Cost: 13
   x,   y  S      X,   Y  F   L  d  Name
   1,   6, 1      6,   9, 0   1  1
   6,   9, 0      6,   7, 1   1  0
END
  $d->svg(file=>"wire3c_u");
 }
#  123456789
# 1.........
# 2.xx....xx
# 3.xx....xx
# 4....xx...
# 5.xx....xx
# 6.xx....xx

#latest:;
if (1)                                                                          #TtotalLength #TSilicon::Chip::Wiring::CompositeWireL::print
 {my  $d = new(width=>10, height=>8);
  $d->wire(x=>2, y=>2, X=>3, Y=>2, n=>"a");
  $d->wire(x=>2, y=>3, X=>3, Y=>3, n=>"b");
  $d->wire(x=>8, y=>2, X=>9, Y=>2, n=>"c");
  $d->wire(x=>8, y=>3, X=>9, Y=>3, n=>"d");

  $d->wire(x=>5, y=>4, X=>6, Y=>4, n=>"CC");

  $d->wire(x=>2, y=>5, X=>3, Y=>5, n=>"A");
  $d->wire(x=>2, y=>6, X=>3, Y=>6, n=>"B");
  $d->wire(x=>8, y=>5, X=>9, Y=>5, n=>"C");
  $d->wire(x=>8, y=>6, X=>9, Y=>6, n=>"D");

  my $c = $d->wire3d(x=>2, y=>4, X=>8, Y=>4, n=>'tl', searchDx=>4, searchDy=>2, debug=>1);
  is_deeply($c->print, <<END);
Cost: 13
   x,   y  S      X,   Y  F   L  d  Name
   2,   4, 1      4,   4, 0   1  0  tl
   4,   4, 0      7,   3, 0   1  1  tl
   7,   3, 0      8,   4, 1   1  1  tl
END

  is_deeply($d->print, <<END);
Length: 31
   x,   y  S      X,   Y  F   L  d  Name
   2,   2, 0      3,   2, 0   1  0  a
   2,   3, 0      3,   3, 0   1  0  b
   8,   2, 0      9,   2, 0   1  0  c
   8,   3, 0      9,   3, 0   1  0  d
   5,   4, 0      6,   4, 0   1  0  CC
   2,   5, 0      3,   5, 0   1  0  A
   2,   6, 0      3,   6, 0   1  0  B
   8,   5, 0      9,   5, 0   1  0  C
   8,   6, 0      9,   6, 0   1  0  D
   2,   4, 1      4,   4, 0   1  0  tl
   4,   4, 0      7,   3, 0   1  1  tl
   7,   3, 0      8,   4, 1   1  1  tl
END
  $d->svg(file=>"wire3d_n");
exit;
 }

#latest:;
if (1)                                                                          #Twire3c
 {my  $d = new(width=>10, height=>8);
  $d->wire(x=>2, y=>2, X=>3, Y=>2);
  $d->wire(x=>2, y=>3, X=>3, Y=>3);
  $d->wire(x=>8, y=>2, X=>9, Y=>2);
  $d->wire(x=>8, y=>3, X=>9, Y=>3);

  $d->wire(x=>5, y=>4, X=>6, Y=>4);

  $d->wire(x=>2, y=>5, X=>3, Y=>5);
  $d->wire(x=>2, y=>6, X=>3, Y=>6);
  $d->wire(x=>8, y=>5, X=>9, Y=>5);
  $d->wire(x=>8, y=>6, X=>9, Y=>6);

  my $c = $d->wire3c(x=>1, y=>4, X=>7, Y=>4);
  is_deeply($d->levels, 1);
  is_deeply($c, [12,
    { d => 0, l => 1, x => 1, X => 4, y => 4, Y => 3, n=>'', s=>1, f=>0 },
    { d => 0, l => 1, X => 7, x => 4, Y => 4, y => 3, n=>'', s=>0, f=>1 },
  ]);

  is_deeply($d->totalLength, 30);

  $d->svg(file=>"wire3c_n");
 }

#latest:;
if (1)                                                                          #TprintLevelsAsCode
 {my  $d = new(width=>10, height=>10);
  ok $d->wire2(x=>1, y=>2, X=>6, Y=>2);
  ok $d->wire2(x=>2, y=>2, X=>5, Y=>2);
  ok $d->wire2(x=>3, y=>2, X=>4, Y=>2);
  is_deeply($d->levels, 3);
  is_deeply($d->printLevelsAsCode([1, 2]), <<'END');
$D->wire2(x=>   1, y=>   2, X=>   6, Y=>   2);
$D->wire2(x=>   2, y=>   2, X=>   5, Y=>   2);
END
  $d->svg(file=>"levels");
 }

#latest:;
if (1)
 {my $d = new(width=>10, height=>10);
  $d->wire2(x=>  1, y=>   3, X=>  3, Y=>   3);
  $d->wire2(x=>  3, y=>   3, X=>  6, Y=>   4);
  is_deeply($d->levels, 2);
  $d->svg(file=>"btree");
 }

#latest:;
if (1)                                                                          #Tdistance
 {is_deeply(distance(2,1,  1, 2), 2);
 }

#latest:;
if (1)                                                                          #TradiateOut
 {my $d = new(width=>5, height=>5);
  my @p = $d->radiateOut(2, 2, 4, 2);
 }

#
# xx       xx
#     xx

#latest:;
if (1)                                                                          #Tprint
 {my $d = new();
  $d->wire(x=>1, y=>1, X=>2, Y=>2, n=>"aaa");
  is_deeply($d->print, <<END);
   x,   y  S      X,   Y  F   L  d  Name
   1,   1, 0      2,   2, 0   1  0  aaa
END
 }

#latest:;
if (1)                                                                          #
 {my $D = new();
  for my $d(0..1)
   { $D->wire(x=>4, y=>4, X=>4, Y=>3, s=>1, f=>1, tested=>1, d=>$d);
#     $D->wire(x=>4, y=>4, X=>5, Y=>4, s=>1, f=>1, tested=>1, d=>$d);
#     $D->wire(x=>4, y=>4, X=>4, Y=>5, s=>1, f=>1, tested=>1, d=>$d);
#     $D->wire(x=>4, y=>4, X=>3, Y=>4, s=>1, f=>1, tested=>1, d=>$d);
   } $D->gds2(outGds=>"sfa");
exit;
 }

#latest:;
if (1)                                                                          #
 {my $D = new();
  for my $d(0..1)
   { $D->wire(x=>1, y=>2, X=>3, Y=>2, s=>1, f=>1, tested=>1, d=>$d);
     $D->wire(x=>6, y=>2, X=>4, Y=>2, s=>1, f=>1, tested=>1, d=>$d);
     $D->wire(x=>2, y=>6, X=>2, Y=>8, s=>1, f=>1, tested=>1, d=>$d);
     $D->wire(x=>4, y=>8, X=>4, Y=>6, s=>1, f=>1, tested=>1, d=>$d);
   } $D->gds2(outGds=>"sfb");
 }

#latest:;
if (1)                                                                          #
 {my $D = new();
  for my $d(0..1)
   { $D->wire(x=>1, y=>2, X=>3, Y=>3, s=>1, f=>1, tested=>1, d=>$d);
     $D->wire(x=>6, y=>2, X=>4, Y=>3, s=>1, f=>1, tested=>1, d=>$d);
     $D->wire(x=>2, y=>6, X=>3, Y=>8, s=>1, f=>1, tested=>1, d=>$d);
     $D->wire(x=>4, y=>8, X=>5, Y=>6, s=>1, f=>1, tested=>1, d=>$d);
   } $D->gds2(outGds=>"sfc");
 }

#latest:;
if (1)                                                                          #
 {my $D = new();
     $D->wire(x=>4, y=>4, X=>4, Y=>3, s=>1, f=>1, tested=>1, d=>0);
     $D->wire(x=>3, y=>3, X=>3, Y=>4, s=>1, f=>1, tested=>1, d=>0);
     $D->gds2(outGds=>"sfa");
exit;
 }

my sub splitSplit($)                                                            # Split lines into a 2d array of characters
 {my ($s) = @_;                                                                 # Options
  my @i = map {[split //, $_]} split /\n/, $s;
  my %i;
  for   my $j(keys @i)
   {for my $i(keys $i[$j]->@*)
     {$i{$i}{$j} = 1 if $i[$j][$i] == '1';
     }
   }
  %i
 }

latest:;
if (1)                                                                          #TfindShortestPath
 {my %i = splitSplit(<<END);
111111
000111
000011
111111
END
  is_deeply([findShortestPath(\%i, \%i, [0, 0], [0,3])], [
  [0, 0, 0],  [1, 0, 0],  [2, 0, 0],  [3, 0, 1],
                                      [3, 1, 0], [4, 1, 1],
                                                 [4, 2, 1],
                                                 [4, 3, 0],
                                      [3, 3, 0],
                          [2, 3, 0],
              [1, 3, 0],
  [0, 3]]);
 }

latest:;
if (1)                                                                          #
 {my %i = splitSplit(<<END);
1111111111
1001110001
0100110001
1111110001
END
  is_deeply([findShortestPath(\%i, \%i, [0, 0], [0,3])], [
  [0, 0, 0],  [1, 0, 0],  [2, 0, 0],  [3, 0, 1],
                                      [3, 1, 0], [4, 1, 1],
                                                 [4, 2, 1],
                                                 [4, 3, 0],
                                      [3, 3, 0],
                          [2, 3, 0],
              [1, 3, 0],
  [0, 3]]);
 }

latest:;
if (1)                                                                          #
 {my %ix = splitSplit(<<END);
11111111111111111111111111111111111111111111111111111111111111111111111111111110
00000000000000000000000000000000000000000000000000000000000000000000000000000000
10111111111111111111111111111111111111111111111111111111111111111111111111111111
00000000000000000000000000000000000000000000000000000000000000000000000000000000
11111111111111111111111111111111111111111111111111111111111111111111111111111110
00000000000000000000000000000000000000000000000000000000000000000000000000000000
10111111111111111111111111111111111111111111111111111111111111111111111111111111
00000000000000000000000000000000000000000000000000000000000000000000000000000000
11111111111111111111111111111111111111111111111111111111111111111111111111111111
END
  my %iy = splitSplit(<<END);
00101010101010101010101010101010101010101000101010101010101010101010101010101010
00000000000000000000000000000000000000000000000000000000000000000000000000000010
00101010101010101010101010101010101010101000101010101010101010101010101010101010
00100000000000000000000000000000000000000000000000000000000000000000000000000000
00101010101010101010101010101010101010101000101010101010101010101010101010101010
00000000000000000000000000000000000000000000000000000000000000000000000000000010
00101010101010101010101010101010101010101000101010101010101010101010101010101010
00100000000000000000000000000000000000000000000000000000000000000000000000000000
00101010101010101010101010101010101010101000101010101010101010101010101010101010
END
  is_deeply([findShortestPath(\%ix, \%iy, [0, 0], [0,8])], [[0, 0, 0],   [1, 0, 0],   [2, 0, 0],   [3, 0, 0],   [4, 0, 0],   [5, 0, 0],   [6, 0, 0],   [7, 0, 0],   [8, 0, 0],   [9, 0, 0],   [10, 0, 0],   [11, 0, 0],   [12, 0, 0],   [13, 0, 0],   [14, 0, 0],   [15, 0, 0],   [16, 0, 0],   [17, 0, 0],   [18, 0, 0],   [19, 0, 0],   [20, 0, 0],   [21, 0, 0],   [22, 0, 0],   [23, 0, 0],   [24, 0, 0],   [25, 0, 0],   [26, 0, 0],   [27, 0, 0],   [28, 0, 0],   [29, 0, 0],   [30, 0, 0],   [31, 0, 0],   [32, 0, 0],   [33, 0, 0],   [34, 0, 0],   [35, 0, 0],   [36, 0, 0],   [37, 0, 0],   [38, 0, 0],   [39, 0, 0],   [40, 0, 0],   [41, 0, 0],   [42, 0, 0],   [43, 0, 0],   [44, 0, 0],   [45, 0, 0],   [46, 0, 0],   [47, 0, 0],   [48, 0, 0],   [49, 0, 0],   [50, 0, 0],   [51, 0, 0],   [52, 0, 0],   [53, 0, 0],   [54, 0, 0],   [55, 0, 0],   [56, 0, 0],   [57, 0, 0],   [58, 0, 0],   [59, 0, 0],   [60, 0, 0],   [61, 0, 0],   [62, 0, 0],   [63, 0, 0],   [64, 0, 0],   [65, 0, 0],   [66, 0, 0],   [67, 0, 0],   [68, 0, 0],   [69, 0, 0],   [70, 0, 0],   [71, 0, 0],   [72, 0, 0],   [73, 0, 0],   [74, 0, 0],   [75, 0, 0],   [76, 0, 0],   [77, 0, 0],   [78, 0, 1],   [78, 1, 1],   [78, 2, 0],   [77, 2, 0],   [76, 2, 0],   [75, 2, 0],   [74, 2, 0],   [73, 2, 0],   [72, 2, 0],   [71, 2, 0],   [70, 2, 0],   [69, 2, 0],   [68, 2, 0],   [67, 2, 0],   [66, 2, 0],   [65, 2, 0],   [64, 2, 0],   [63, 2, 0],   [62, 2, 0],   [61, 2, 0],   [60, 2, 0],   [59, 2, 0],   [58, 2, 0],   [57, 2, 0],   [56, 2, 0],   [55, 2, 0],   [54, 2, 0],   [53, 2, 0],   [52, 2, 0],   [51, 2, 0],   [50, 2, 0],   [49, 2, 0],   [48, 2, 0],   [47, 2, 0],   [46, 2, 0],   [45, 2, 0],   [44, 2, 0],   [43, 2, 0],   [42, 2, 0],   [41, 2, 0],   [40, 2, 0],   [39, 2, 0],   [38, 2, 0],   [37, 2, 0],   [36, 2, 0],   [35, 2, 0],   [34, 2, 0],   [33, 2, 0],   [32, 2, 0],   [31, 2, 0],   [30, 2, 0],   [29, 2, 0],   [28, 2, 0],   [27, 2, 0],   [26, 2, 0],   [25, 2, 0],   [24, 2, 0],   [23, 2, 0],   [22, 2, 0],   [21, 2, 0],   [20, 2, 0],   [19, 2, 0],   [18, 2, 0],   [17, 2, 0],   [16, 2, 0],   [15, 2, 0],   [14, 2, 0],   [13, 2, 0],   [12, 2, 0],   [11, 2, 0],   [10, 2, 0],   [9, 2, 0],   [8, 2, 0],   [7, 2, 0],   [6, 2, 0],   [5, 2, 0],   [4, 2, 0],   [3, 2, 0],   [2, 2, 1],   [2, 3, 1],   [2, 4, 0],   [3, 4, 0],   [4, 4, 0],   [5, 4, 0],   [6, 4, 0],   [7, 4, 0],   [8, 4, 0],   [9, 4, 0],   [10, 4, 0],   [11, 4, 0],   [12, 4, 0],   [13, 4, 0],   [14, 4, 0],   [15, 4, 0],   [16, 4, 0],   [17, 4, 0],   [18, 4, 0],   [19, 4, 0],   [20, 4, 0],   [21, 4, 0],   [22, 4, 0],   [23, 4, 0],   [24, 4, 0],   [25, 4, 0],   [26, 4, 0],   [27, 4, 0],   [28, 4, 0],   [29, 4, 0],   [30, 4, 0],   [31, 4, 0],   [32, 4, 0],   [33, 4, 0],   [34, 4, 0],   [35, 4, 0],   [36, 4, 0],   [37, 4, 0],   [38, 4, 0],   [39, 4, 0],   [40, 4, 0],   [41, 4, 0],   [42, 4, 0],   [43, 4, 0],   [44, 4, 0],   [45, 4, 0],   [46, 4, 0],   [47, 4, 0],   [48, 4, 0],   [49, 4, 0],   [50, 4, 0],   [51, 4, 0],   [52, 4, 0],   [53, 4, 0],   [54, 4, 0],   [55, 4, 0],   [56, 4, 0],   [57, 4, 0],   [58, 4, 0],   [59, 4, 0],   [60, 4, 0],   [61, 4, 0],   [62, 4, 0],   [63, 4, 0],   [64, 4, 0],   [65, 4, 0],   [66, 4, 0],   [67, 4, 0],   [68, 4, 0],   [69, 4, 0],   [70, 4, 0],   [71, 4, 0],   [72, 4, 0],   [73, 4, 0],   [74, 4, 0],   [75, 4, 0],   [76, 4, 0],   [77, 4, 0],   [78, 4, 1],   [78, 5, 1],   [78, 6, 0],   [77, 6, 0],   [76, 6, 0],   [75, 6, 0],   [74, 6, 0],   [73, 6, 0],   [72, 6, 0],   [71, 6, 0],   [70, 6, 0],   [69, 6, 0],   [68, 6, 0],   [67, 6, 0],   [66, 6, 0],   [65, 6, 0],   [64, 6, 0],   [63, 6, 0],   [62, 6, 0],   [61, 6, 0],   [60, 6, 0],   [59, 6, 0],   [58, 6, 0],   [57, 6, 0],   [56, 6, 0],   [55, 6, 0],   [54, 6, 0],   [53, 6, 0],   [52, 6, 0],   [51, 6, 0],   [50, 6, 0],   [49, 6, 0],   [48, 6, 0],   [47, 6, 0],   [46, 6, 0],   [45, 6, 0],   [44, 6, 0],   [43, 6, 0],   [42, 6, 0],   [41, 6, 0],   [40, 6, 0],   [39, 6, 0],   [38, 6, 0],   [37, 6, 0],   [36, 6, 0],   [35, 6, 0],   [34, 6, 0],   [33, 6, 0],   [32, 6, 0],   [31, 6, 0],   [30, 6, 0],   [29, 6, 0],   [28, 6, 0],   [27, 6, 0],   [26, 6, 0],   [25, 6, 0],   [24, 6, 0],   [23, 6, 0],   [22, 6, 0],   [21, 6, 0],   [20, 6, 0],   [19, 6, 0],   [18, 6, 0],   [17, 6, 0],   [16, 6, 0],   [15, 6, 0],   [14, 6, 0],   [13, 6, 0],   [12, 6, 0],   [11, 6, 0],   [10, 6, 0],   [9, 6, 0],   [8, 6, 0],   [7, 6, 0],   [6, 6, 0],   [5, 6, 0],   [4, 6, 0],   [3, 6, 0],   [2, 6, 1],   [2, 7, 1],   [2, 8, 0],   [1, 8, 0],   [0, 8]]);
 }

&done_testing;
finish: 1
