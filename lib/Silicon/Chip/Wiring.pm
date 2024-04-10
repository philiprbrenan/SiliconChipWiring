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

#  Vertical
#  Y cross bar  There are 4 sub levels within each wiring level. The sub levels are connected by the vertical vias described in the next comment.
#  Insulation   The sea of gates is formed at level 0 and is pre-manufactured by the wafer vendor.  Our job is just to connect them.
#  X cross bar
#  Insulation

#  Horizontal
#  ..y        Each cell is divided into 16 sub cells that are arranged to permit
#  xxyx       the via (V) connect with the X and Y crossbars.  There is a layer
#  ..y.       of insulation under each of the X and Y cross bars making 4 sub
#  V.y.       levels per level.  The dots . represent areas with no metal so
#             they do not conduct unless metal is added during lithography.
# During wire connection connection, the . next to V are assumed to have metal so that the via can connect to the crossbars.

makeDieConfess;

my $debug = 0;                                                                  # Debug if set
sub debugMask {1}                                                               # Adds a grid to the drawing of a bus line

#D1 Construct                                                                   # Create a Silicon chip wiring diagram on one or more levels as necessary to make the connections requested.

sub new(%)                                                                      # New wiring diagram.
 {my (%options) = @_;                                                           # Options

  my ($w, $h) = @options{qw(width height)};
  defined($w) or confess "w";
  defined($h) or confess "h";

  my $d = genHash(__PACKAGE__,                                                  # Wiring diagram
    %options,                                                                   # Options
    width  => $options{width},                                                  # Width of chip
    height => $options{height},                                                 # Height of chip
    wires  => [],                                                               # Wires on diagram
    levels => 0,                                                                # Levels in use
    levelX => {},                                                               # {level}{x}{y} - available cells in X  - used cells are deleted. Normally if present the cell, if present has a positive value.  If it has a negative it is a temporary addition for the purpose of connecting the end points of the wires to the vertical vias.
    levelY => {},                                                               # {level}{x}{y} - available cells in Y
   );

  $d->newLevel;                                                                 # Create the first level
  $d
 }

sub newLevel($%)                                                                #P Make a new level and return its number
 {my ($diagram, %options) = @_;                                                 # Diagram, Options

  my ($w, $h) = @$diagram{qw(width height)};
  defined($w) or confess "w";
  defined($h) or confess "h";

  my $l = ++$diagram->levels;                                                   # Next level

  my %lx; my %ly;
  for   my $x(0..$diagram->width)                                               # Load the next level
   {for my $y(0..$diagram->height)
     {$lx{$x*4+$_}{$y*4+2}  = $l for 0..3;                                      # Each cell consists of 16 small squares. The via is in position 0,0.  The x connectors run along y == 2. The y connectors run along x == 2.  This arrangement allows to add the start and end via and its vicinity when creating connections
      $ly{$x*4+2} {$y*4+$_} = $l for 0..3;
     }
   }

  $diagram->levelX->{$l} = {%lx};                                               # X cells available in new level
  $diagram->levelY->{$l} = {%ly};                                               # Y cells available in new level

  $l                                                                            # Level number
 }

sub wire($%)                                                                    # New wire on a wiring diagram.
 {my ($diagram, %options) = @_;                                                 # Diagram, options

  my ($x, $X, $y, $Y) = @options{qw(x X y Y)};
  defined($x) or confess "x";
  defined($y) or confess "y";
  defined($X) or confess "X";
  defined($Y) or confess "Y";
  $x == $X and $y == $Y and confess "Start and end of connection are in the same cell";
#say STDERR "IIII ", dump($diagram->levels) if $options{debug};

  my $w = genHash(__PACKAGE__,                                                  # Wire
    x => $x,                                                                    # Start x position of wire
    X => $X,                                                                    # End   x position of wire
    y => $y,                                                                    # Start y position of wire
    Y => $Y,                                                                    # End   y position of wire
    l => undef,                                                                 # Level on which wore is drawn
    n => $options{n}//'',                                                       # Optional name
    p => [],                                                                    # Path from start to finish
   );

  my sub fillInAroundVia($$$$$)                                                 # Fill in the squares around a via so that it can connect to the nearest x crossbar above or the nearest y cross bar to the right.
   {my ($m, $x, $y, $l, $v) = @_;                                               # Layer mask showing available cells, $x , $y position of via, level, value to place or delete if undef
    my $w = $diagram->width; my $h = $diagram->height;

    my sub setOrUnset($$)                                                       # Set a sub cell or clear it by deleting it
     {my ($i, $j) = @_;                                                         # Position to set or clear
      my $px = $x*4+$i; my $py = $y*4+$j;
      return if $px < 0 or $py < 0 or $px > $w*4 or $py > $h*4;                 # Sub cell out of range
      if (defined $v)
       {$m->{$px}{$py} = $v;                                                    # Set sub cell as having metal
       }
      else
       {delete $m->{$px}{$py};                                                  # Remove metal from sub cell
       }
     }
    setOrUnset(-1, 0); setOrUnset( 0, 0); setOrUnset(+1, 0);                    # Horizontally
    setOrUnset(0, -1);                    setOrUnset(0, +1);                    # Vertically
   }

  my @P; my $L;                                                                 # Shortest path over existing layers, layer for shortest path

  my sub pathOnLevel($)                                                         # Find shortest path on the specified level
   {my ($l) = @_;                                                               # Level
    my $lx = $diagram->levelX->{$l};                                            # X cells available on this level
    my $ly = $diagram->levelY->{$l};                                            # Y cells available on this level
    fillInAroundVia($_, $x, $y, $l, 22) for $lx, $ly;                           # Add metal around via so it can connect to the crossbars
    fillInAroundVia($_, $X, $Y, $l, 22) for $lx, $ly;
    my @p = $diagram->findShortestPath($lx, $ly, [$x*4, $y*4], [$X*4, $Y*4], %options);
    if (@p and !@P || @p < @P)                                                  # Shorter path on this level
     {@P = @p;
      $L = $l;
      #say STDERR "LLLL ", dump($L) if $options{debug};
     }
    fillInAroundVia($_, $x, $y, $l, undef) for $lx, $ly;                        # Remove metal
    fillInAroundVia($_, $X, $Y, $l, undef) for $lx, $ly;
   }

  for my $l(1..$diagram->levels)                                                # Find best level to place wire
   {pathOnLevel($l);
    last if @P and $options{placeFirst};                                        # Exit as soon as a level is found that can take the wire regardless of length. This allows us to find the wires that force the creation of new layers.
   }

  if (!@P)                                                                      # Have to create a new level for this wire
   {my $l = $diagram->newLevel;
#    say STDERR "MMMMM ", dump($L) if $options{debug};
    pathOnLevel($l);
   }
  @P or confess <<"END" =~ s/\n(.)/ $1/gsr;                                     # The new layer should always resolve this problem, but just in case.
Cannot connect [$x, $y] to [$X, $Y]
END

  if (@P)                                                                       # Remove path from further consideration
   {my $l = $w->l = $L;
    my $lx = $diagram->levelX->{$l};                                            # X cells available on this level
    my $ly = $diagram->levelY->{$l};                                            # Y cells available on this level
#    say STDERR "NNNNN", dump($L) if $options{debug};
    for my $p(@P)                                                               # Remove cells occupied by path so that they are not used ion some other path
     {my ($x, $y, $d) = @$p;                                                    # Point on wire, direction 0 - x, 1 y to step to next point
      if (defined $d)                                                           # There is no step indicator on the last point of the path because there is nowhere to step from it. The area immediately around the via is cleared when the temporary cells added to connect the via to the neighboring bus are deleted.
       {if ($d == 0)                                                            # Remove step in X
         {delete $$lx{$x}{$y}; delete $$lx{$x-1}{$y}; delete $$lx{$x+1}{$y};    # Remove step in X
         }
        else
         {delete $$ly{$x}{$y}; delete $$ly{$x}{$y-1}; delete $$ly{$x}{$y+1};    # Remove step in Y
         }
       }
     }
   }

#  say STDERR "OOOO", dump($L, \@P) if $options{debug};
  $w->p = [@P];                                                                 # Path followed by wire.
  push $diagram->wires->@*, $w;                                                 # Save wire
  $w                                                                            # The wire
 }

sub numberOfWires($%)                                                           # Number of wires in the diagram
 {my ($D, %options) = @_;                                                       # Diagram, options
  scalar $D->wires->@*
 }

sub length($$)                                                                  # Length of a wire in a diagram
 {my ($D, $w) = @_;                                                             # Diagram, wire
  scalar $w->p->@*                                                              # The length of the path
 }

sub totalLength($)                                                              # Total length of wires
 {my ($d) = @_;                                                                 # Diagram
  my @w = $d->wires->@*;
  my $l = 0; $l += $d->length($_) for @w;                                       # Add length of each wire
  $l
 }

sub findShortestPath($$$$$%)                                                    # Find the shortest path between two points in a two dimensional image stepping only from/to adjacent marked cells. The permissible steps are given in two imahes, one for x steps and one for y steps.
 {my ($diagram, $imageX, $imageY, $start, $finish, %options) = @_;              # Diagram, ImageX{x}{y}, ImageY{x}{y}, start point, finish point, options
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

  my sub search                                                                 # Search for the shortest path
   {for my $d(2..1e6)                                                           # Depth of search
     {last unless keys %o;                                                      # Keep going until we cannot go any further
#say STDERR "AAAA $d" if $options{debug};

      my %n;                                                                    # Cells at new edge of search
      for   my $x(sort keys %o)                                                 # Current frontier x
       {for my $y(sort keys $o{$x}->%*)                                         # Current frontier y
         {my sub check($$)                                                      # Search from a point in the current frontier
           {my ($x, $y) = @_;                                                   # Point to test
            if ($ix{$x}{$y} || $iy{$x}{$y} and !exists $b{$x}{$y})              # Located a new unclassified cell
             {$d{$d}{$x}{$y} = $n{$x}{$y} = $b{$x}{$y} = $d;                    # Set depth for cell and record is as being at that depth
              if ($x == $X && $y == $Y)                                         # Reached target
               {#say STDERR "BBBB", &printHash(\%b) if $options{debug};
                return 1;                                                       # Reached target
               }
             }
           }
          my $f = check($x-1, $y)   || check($x+1, $y) ||                       # Check in x
                  check($x,   $y-1) || check($x,   $y+1);                       # Check in Y
          return 1 if $f;                                                       # Reached target
         }
       }
#     say STDERR "AAAA", &printHash(\%n) if $options{debug};
      %o = %n;                                                                  # The new frontier becomes the settled fontoer
     }
    ''
   }
  my $f = search;                                                               # Search for the shortest path to the target point

#  say STDERR "CCCC f=$f ", dump($b{$X}{$Y}), "  ", &printHash(\%b) if $options{debug};
  return () unless my $N = $b{$X}{$Y};                                          # Return empty list if there is no path from the start to the finish
#  say STDERR "DDDD" if $options{debug};
# say STDERR &printHash(\%b);

  my sub path($)                                                                # Finds a shortest path and returns the number of changes of direction and the path itself
   {my ($favorX) = @_;                                                          # Favor X step at start of back track if true else favor y
    my @p = [$X, $Y];                                                           # Shortest path
    my ($x, $y, $d) = ($X, $Y, $N);                                             # Work back from end point
    my $s; my $S;                                                               # Direction of last step
    my $c = 0;                                                                  # Number of changes
    for my $d(reverse 1..$N-1)                                                  # Work backwards
     {my %d = $d{$d}->%*;

      push @p, [($x, $y, $S) = ($favorX ? defined($s) && $s == 0 : !defined($s) || $s == 0) ?                      # Preference for step in x
       ($d{$x-1}{$y} ? ($x-1, $y, 0) :
        $d{$x+1}{$y} ? ($x+1, $y, 0) :
        $d{$x}{$y-1} ? ($x, $y-1, 1) : ($x, $y+1, 1))
       :
       ($d{$x}{$y-1} ? ($x, $y-1, 1) :                                          # Preference for step in y
        $d{$x}{$y+1} ? ($x, $y+1, 1) :
        $d{$x-1}{$y} ? ($x-1, $y, 0) : ($x+1, $y, 0))];
      ++$c if defined($s) and defined($S) and $s != $S;                         # Count changes of direction
      $s = $S                                                                   # Continue in the indicated direction
     }

    ($c, [reverse @p])
   }
  my ($q, $Q) = path(1);                                                        # Favor X at start of back track from finish to start
  my ($p, $P) = path(0);                                                        # Favor Y at start of back track from finish to start
  #say STDERR "EEEE", dump($Q, $P) if $options{debug};
  $q < $p ? @$Q : @$P                                                           # Path with least changes of direction
 }

#D1 Visualize                                                                   # Visualize a Silicon chip wiring diagrams

my sub wireHeader()                                                             #P Wire header
 {"   x,   y      X,   Y   L  Name    Path";
 }

sub printCode($%)                                                               # Print code to create a diagram
 {my ($d, %options) = @_;                                                       # Drawing, options
  my @t;
  for my $w($d->wires->@*)
   {my ($x, $y, $X, $Y) = @$w{qw(x y X Y)};
    push @t, sprintf "\$d->wire(x=>%2d, y=>%2d, X=>%2d, Y=>%2d);", $x, $y, $X, $Y;
   }
  join "\n", @t, ''
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

sub printInOrder($%)                                                            # Print a diagram
 {my ($d, %options) = @_;                                                       # Drawing, options
  my @t; my $l = 0;
  push @t, wireHeader;
  for my $w(
            sort {$a->x <=> $b->x}                                              # Sort wires into order
            sort {$a->y <=> $b->y}
            sort {$a->X <=> $b->X}
            sort {$a->Y <=> $b->Y}
            $d->wires->@*)
   {push @t, $d->printWire($w);
    $l += $d->length($w);
   }
  unshift @t, "Length: $l";
  join "\n", @t, ''
 }

sub printWire($$)                                                               # Print a wire to a string
 {my ($D, $W) = @_;                                                             # Drawing, wire
  my ($x, $y, $X, $Y, $l, $n, $p) = @$W{qw(x y X Y l n p)};
  sprintf "%4d,%4d   %4d,%4d  %2d  %-8s".(join '  ', map{join ',', @$_} @$p), $x, $y, $X, $Y, $l, $n
 }

sub printPath($)                                                                # Print a path as a two dimensional character image
 {my ($P) = @_;                                                                 # Path

  my $X; my $Y;
  for my $p(@$P)                                                                # Find dimensions of path
   {my ($x, $y, $s) = @$p;
    $X = maximum($X, $x); $Y = maximum($Y, $y);
   }

  my @s = ('.' x (1+$X)) x (1+$Y);                                              # Empty image

  for my $p(@$P)                                                                # Along the path
   {my ($x, $y, $s) = @$p;
    substr($s[$y], $x, 1) = $s//'.';
   }
  substr($s[$$P[ 0][1]], $$P[ 0][0], 1) = 'S';                                  # Finish
  substr($s[$$P[-1][1]], $$P[-1][0], 1) = 'F';                                  # Finish
  join "\n", @s, '';
 }

sub printHash($)                                                                #P Print a two dimensional hash
 {my ($x) = @_;                                                                 # Two dimensional hash
  my %x = $x->%*;

  my $w = 0; my $h = 0;
  for   my $x(sort keys %x)                                                     # Size of image
   {for my $y(sort keys $x{$x}->%*)
     {$w = maximum($w, $x);
      $h = maximum($h, $y);
     }
   }

  my @s = (' ' x (4+$w)) x (4+$h);                                              # Empty image
  for   my $x(sort keys %x)                                                     # Load image
   {for my $y(sort keys $x{$x}->%*)
     {substr($s[$y], $x, 1) = substr("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ", $x{$x}{$y} % 30, 1);
     }
   }
  my $s = join "\n", @s, '';
  $s =~ s(\s+\n) (\n)gs;
  $s                                                                            # Image as lines
 }

my sub printOverlays($$)                                                        # Print two overlaid two dimensional hash
 {my ($x, $y) = @_;                                                             # Two dimensional hashes
  my %x = $x->%*; my %y = $y->%*;

  my $w; my $h;
  for   my $x(sort keys %x)                                                     # Size of image
   {for my $y(sort keys $x{$x}->%*)
     {$w = maximum($w, $x);
      $h = maximum($h, $y);
     }
   }

  my @s = (' ' x (4+$w)) x (4+$h);                                              # Empty image
  for   my $x(sort keys %x)
   {for my $y(sort keys $x{$x}->%*)
     {substr($s[$y], $x, 1) = 1;
     }
   }

  for   my $x(sort keys %y)
   {for my $y(sort keys $y{$x}->%*)
     {substr($s[$y], $x, 1) = substr($s[$y], $x, 1) eq ' ' ? '2' : '3';
     }
   }
  my $s = join "\n", @s, '';
  $s =~ s(\s+\n) (\n)gs;
  $s
 }

sub printCells($$)                                                              #P Print the cells and sub cells in a diagram
 {my ($diagram, $level) = @_;                                                   # Diagram

  printOverlays($diagram->levelX->{$level}, $diagram->levelY->{$level});
 }

sub svg($%)                                                                     # Draw the bus lines by level.
 {my ($D, %options) = @_;                                                       # Wiring diagram, options

  if (defined(my $l = $options{level}))                                         # Draw the specified level
   {$D->svgLevel($l, %options);
   }
  else                                                                          # Draw all levels
   {my $L = $D->levels;
    my @s;
    for my $l(1..$L)
     {push @s, $D->svgLevel($l, %options);                                      # Write each level into a separate file
     }
    @s
   }
 }

my sub darkSvgColor                                                             # Generate a random dark color in hexadecimal format
 {my $c = int rand 3;
  my @r = map {int rand 128} 1..3;
  $r[$c] *= 2;

  sprintf "#%02X%02X%02X", @r;
 }

my sub distance($$$$)                                                           # Manhattan distance between two points
 {my ($x, $y, $X, $Y) = @_;                                                     # Start x, start y, end x, end y
  abs($X - $x) + abs($Y - $y)
 }

my sub collapsePath($)                                                          # Collapse a path to reduce the number of svg commands and thus the size of the svg files
 {my ($p) = @_;                                                                 # Path to collapse
           # Start   # Finish  # Direction
  my @c = [$$p[0],   $$p[0],   0];                                              # Collapse the path to reduce the number of svg commands.
  for my $i(1..$#$p)                                                            # Index path
   {my @q = $$p[$i]->@*;                                                        # Current element of path
    my @o = $c[-1][0]->@*;                                                      # Start of previous extension
    if ($o[0] != $q[0] and $o[1] != $q[1])                                      # New direction
     {push @c, [[@q], [@q]];
     }
    else
     {$c[-1][1] = [@q];
     }
   }

  if (@c == 1) {$c[0][2] = $c[0][0][2]}                                         # Straight line so direction is the same as the step away from the via
  else                                                                          # At least three segments
   {for my $i(1..@c-2)                                                          # Index path
     {$c[$i][2] = $c[$i][0][0] != $c[$i][1][0]? 0 : 1;                          # Direction of change
     }
    $c[ 0][2] = $c[1][2];                                                       # Step from first via is the same as first cross bar
    $c[-1][2] = $c[-2][2];                                                      # Step to last    via is the same as last  cross bar
   }

  @c                                                                            # Collapsed path [[start x, start y], [finish x, finish y], level]
 }

sub svgLevel($$%)                                                               #P Draw the bus lines by level.
 {my ($D, $level, %options) = @_;                                               # Wiring diagram, level, options

  my @defaults = (defaults=>                                                    # Default values
   {stroke_width => 0.5,
    opacity      => 0.75,
    stroke       => "transparent",
    fill         => "transparent",
   });

  my $svg = Svg::Simple::new(@defaults, %options, grid=>debugMask ? 1 : 0);     # Draw each wire via Svg. Grid set to 1 produces a grid that can be helpful debugging layout problems

  for my $w($D->wires->@*)                                                      # Each wire in X
   {my ($l, $p) = @$w{qw(l p)};                                                 # Level and path
    next unless $l == $level;                                                   # Draw the specified level

    my @c = collapsePath($p);                                                   # Collapse the path to reduce the number of svg commands
    my $C = darkSvgColor;                                                       # Dark color

    for my $i(keys @c)                                                          # Index collapsed path
     {my $q = $c[$i];                                                           # Element of path
      my ($c, $d) = @$q;                                                        # Coordinates, dimensions
      my ($x, $y) = @$c;                                                        # Coordinates at start
      my ($X, $Y) = @$d;                                                        # Coordinates at end
      $x < $X ? $X++ : ++$x;
      $y < $Y ? $Y++ : ++$y;
      $x /= 4; $y /= 4; $X /= 4; $Y /= 4;                                       # Scale
      $svg->path(d=>"M $x $y L $X $y L $X $Y L $x $Y Z", fill=>$C);             # Rectangle as a path matching the gds2 implementation
      if ($i > 0 and $c[$i][2] != $c[$i-1][2])                                  # Change of level due to change of direction
       {my ($x, $y) = $c[$i-1][1]->@*;                                          # Coordinates of end of previous section
        my ($cx, $cy) = (($x+1/3)/4, ($y+1/3)/4);                               # Start of last sub cell of previous segment
        my ($dx, $dy) = (($x+2/3)/4, ($y+2/3)/4);                               # Far edge of last sub cell of previous segment
        $svg->path(d=>"M $cx $cy L $dx $cy L $dx $dy L $cx $dy Z", stroke=>"black", stroke_width=>1/48); # Show change of level
       }
     }
     my sub cd($$)                                                              # Coordinates of a start or end point
      {my ($i, $j) = @_;                                                        # Index for point, coordinate in point
       $$p[$i][$j] / 4
      }
     $svg->rect(x=>cd( 0, 0), y=>cd( 0, 1), width=>1/4, height=>1/4, fill=>"darkGreen");  # Draw start of wire
     $svg->rect(x=>cd(-1, 0), y=>cd(-1, 1), width=>1/4, height=>1/4, fill=>"darkRed");    # Draw end   of wire
   }

  my $t = $svg->print(width=>$D->width+1, height=>$D->height+1);                # Text of svg

  if (my $f = $options{svg})                                                    # Optionally write to an svg file
   {my $F = fpe q(svg), "${f}_$level", q(svg);                                  # Write each level into a separate file
    confess "Wiring file already exists: $F\n" if -e $F;
    owf($F, $t)
   }

  $t
 }

sub gds2($%)                                                                    # Draw the wires using GDS2
 {my ($diagram, %options) = @_;                                                 # Wiring diagram, output file, options
  my $gdsBlock  = $options{block};                                              # Existing GDS2 block
  my $gdsOut    = $options{svg};                                                # Write a newly created gds2 block to this file in the gds sub folder
  my $delta     = 1/4;                                                          # Offset from edge of each gate cell
  my $wireWidth = 1/4;                                                          # Width of a wire

  my $g = sub                                                                   # Draw as Graphics Design System 2 either inside an existing gds file or create a new one
   {return $gdsBlock if defined $gdsBlock;                                      # Drawing in an existing block
    createEmptyFile(my $f = fpe q(gds), $gdsOut, q(gds));                       # Make gds folder
    my $g = new GDS2(-fileName=>">$f");                                         # Draw as Graphics Design System 2
    $g->printInitLib(-name=>$gdsOut);
    $g->printBgnstr (-name=>$gdsOut);
    $g
   }->();

  my $s  = $wireWidth/2;                                                        # Half width of the wire
  my $t  = 1/2 + $s;                                                            # Center of wire
  my $S  = $wireWidth; # 2 * $s                                                 # Width of wire
  my @w  = $diagram->wires->@*;                                                 # Wires
  my $Nl = 4;                                                                   # Wiring layers within each level

  my $levels = $diagram->levels;                                                # Levels
  my $width  = $diagram->width;                                                 # Width
  my $height = $diagram->height;                                                # Height

  for my $wl(1..$levels)                                                        # Vias
   {for my $l(0..$Nl-1)                                                         # Insulation, x layer, insulation, y layer
     {for   my $x(0..$width)                                                    # Gate io pins run vertically along the "vias"
       {for my $y(0..$height)
         {my $x1 = $x; my $y1 = $y;
          my $x2 = $x1 + $wireWidth; my $y2 = $y1 + $wireWidth;
          $g->printBoundary(-layer=>$wl*$Nl+$l, -xy=>[$x1,$y1, $x2,$y1, $x2,$y2, $x1,$y2]); # Via
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

  my sub via($$$)                                                               # Draw a vertical connector. The vertical connectors are known as vias and transmit the gate inputs and outputs to the various wiring layers.
   {my ($x, $y, $l) = @_;                                                       # Options
    $g->printBoundary(-layer=>$l*$Nl+2, -xy=>[$x-$s,$y-$s, $x+$s,$y-$s, $x+$s,$y+$s, $x-$s,$y+$s]); # Vertical connector
   }

  #say STDERR wireHeader;
  for my $j(keys @w)                                                            # Layout each wire
   {my $w = $w[$j];
    my ($l, $p) = @$w{qw(l p)};
    my @c = collapsePath($p);                                                   # Collapse the path

    for my $i(keys @c)                                                          # Index collapsed path
     {my $q = $c[$i];                                                           # Element of path
      my ($c, $d) = @$q;                                                        # Coordinates, dimensions
      my ($x, $y) = @$c;                                                        # Coordinates at start
      my ($X, $Y) = @$d;                                                        # Coordinates at end
      $x < $X ? $X++ : ++$x;
      $y < $Y ? $Y++ : ++$y;
      $x /= 4; $y /= 4; $X /= 4; $Y /= 4;                                       # Scale

      my $L = $l * $Nl + ($$q[2] ? 2 : 0);                                      # Sub level in wiring level
      my $I = $l * $Nl + 1;                                                     # The insulation layer between the x and y crossbars.  We connect the x cross bars to the y cross bars through this later everytime we change direction in a wiring level.

      $g->printBoundary(-layer=>$L, -xy=>[$x,$y, $X,$y, $X,$Y, $x,$Y]);         # Fill in cell
      if ($i > 0 and $c[$i][2] != $c[$i-1][2])                                  # Change of level
       {$g->printBoundary(-layer=>$I, -xy=>[$X,$Y, $X-1/4,$Y, $X-1/4,$Y-1/4, $X,$Y-1/4]); # Step though insulation layer to connect the X crossbar to the Y crossbar.
       }
      $g->printText(-xy=>[$x+1/8, $y+1/8], -string=>($j+1).".$i");              # Y coordinate
     }
   }

  if (!defined($gdsBlock))                                                      # Close the library if a new ine is being defined
   {$g->printEndstr;
    $g->printEndlib;
   }
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

#svg https://raw.githubusercontent.com/philiprbrenan/SiliconChipWiring/main/lib/Silicon/Chip/svg/

=pod

=encoding utf-8

=for html <p><a href="https://github.com/philiprbrenan/SiliconChipWiring"><img src="https://github.com/philiprbrenan/SiliconChipWiring/workflows/Test/badge.svg"></a>

=head1 Name

Silicon::Chip::Wiring - Wire up a L<silicon|https://en.wikipedia.org/wiki/Silicon> L<chip|https://en.wikipedia.org/wiki/Integrated_circuit> to combine L<logic gates|https://en.wikipedia.org/wiki/Logic_gate> to transform software into hardware.

file:///home/phil/perl/cpan/SiliconChipWiring/lib/Silicon/Chip/svg/xy2_1.svg

=head1 Synopsis

=head2 Wire up a silicon chip

=for html <p><img src="https://raw.githubusercontent.com/philiprbrenan/SiliconChipWiring/main/lib/Silicon/Chip/svg/xy2_1.svg">


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


Version 20240331.


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


=for html <img src="https://raw.githubusercontent.com/philiprbrenan/SiliconChipWiring/main/lib/Silicon/Chip/png/xy2.png">


=for html <img src="https://raw.githubusercontent.com/philiprbrenan/SiliconChipWiring/main/lib/Silicon/Chip/png/xy2_1.png">


=for html <img src="https://raw.githubusercontent.com/philiprbrenan/SiliconChipWiring/main/lib/Silicon/Chip/png/xy2_2.png">


=head2 wire($diagram, %options)

New wire on a wiring diagram.

     Parameter  Description
  1  $diagram   Diagram
  2  %options   Options

B<Example:>


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


=for html <img src="https://raw.githubusercontent.com/philiprbrenan/SiliconChipWiring/main/lib/Silicon/Chip/png/xy2.png">


=for html <img src="https://raw.githubusercontent.com/philiprbrenan/SiliconChipWiring/main/lib/Silicon/Chip/png/xy2_1.png">


=for html <img src="https://raw.githubusercontent.com/philiprbrenan/SiliconChipWiring/main/lib/Silicon/Chip/png/xy2_2.png">


=head2 numberOfWires   ($D, %options)

Number of wires in the diagram

     Parameter  Description
  1  $D         Diagram
  2  %options   Options

B<Example:>


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


=for html <img src="https://raw.githubusercontent.com/philiprbrenan/SiliconChipWiring/main/lib/Silicon/Chip/svg/x1.svg">


=head2 length  ($D, $w)

Length of a wire in a diagram

     Parameter  Description
  1  $D         Diagram
  2  $w         Wire

B<Example:>


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


=for html <img src="https://raw.githubusercontent.com/philiprbrenan/SiliconChipWiring/main/lib/Silicon/Chip/svg/y1.svg">


=for html <img src="https://raw.githubusercontent.com/philiprbrenan/SiliconChipWiring/main/lib/Silicon/Chip/svg/y1_1.svg">


=head2 totalLength ($d)

Total length of wires

     Parameter  Description
  1  $d         Diagram

B<Example:>


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


=for html <img src="https://raw.githubusercontent.com/philiprbrenan/SiliconChipWiring/main/lib/Silicon/Chip/png/xy2.png">


=for html <img src="https://raw.githubusercontent.com/philiprbrenan/SiliconChipWiring/main/lib/Silicon/Chip/png/xy2_1.png">


=for html <img src="https://raw.githubusercontent.com/philiprbrenan/SiliconChipWiring/main/lib/Silicon/Chip/png/xy2_2.png">


=head2 findShortestPath($diagram, $imageX, $imageY, $start, $finish)

Find the shortest path between two points in a two dimensional image stepping only from/to adjacent marked cells. The permissible steps are given in two imahes, one for x steps and one for y steps.

     Parameter  Description
  1  $diagram   Diagram
  2  $imageX    ImageX{x}{y}
  3  $imageY    ImageY{x}{y}
  4  $start     Start point
  5  $finish    Finish point

B<Example:>


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


=head1 Visualize

Visualize a Silicon chip wiring diagrams

=head2 print   ($d, %options)

Print a diagram

     Parameter  Description
  1  $d         Drawing
  2  %options   Options

B<Example:>


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


=head2 printWire   ($D, $W)

Print a wire to a string

     Parameter  Description
  1  $D         Drawing
  2  $W         Wire

B<Example:>


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


=head2 printPath   ($P)

Print a path as a two dimensional character image

     Parameter  Description
  1  $P         Path

B<Example:>


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


=for html <img src="https://raw.githubusercontent.com/philiprbrenan/SiliconChipWiring/main/lib/Silicon/Chip/svg/xy1.svg">


=for html <img src="https://raw.githubusercontent.com/philiprbrenan/SiliconChipWiring/main/lib/Silicon/Chip/svg/xy1_1.svg">


=head2 svg ($D, %options)

Draw the bus lines by level.

     Parameter  Description
  1  $D         Wiring diagram
  2  %options   Options

B<Example:>


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


=for html <img src="https://raw.githubusercontent.com/philiprbrenan/SiliconChipWiring/main/lib/Silicon/Chip/svg/y1.svg">


=for html <img src="https://raw.githubusercontent.com/philiprbrenan/SiliconChipWiring/main/lib/Silicon/Chip/svg/y1_1.svg">


=head2 gds2($diagram, %options)

Draw the wires using GDS2

     Parameter  Description
  1  $diagram   Wiring diagram
  2  %options   Output file

B<Example:>


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


=for html <img src="https://raw.githubusercontent.com/philiprbrenan/SiliconChipWiring/main/lib/Silicon/Chip/svg/y1.svg">


=for html <img src="https://raw.githubusercontent.com/philiprbrenan/SiliconChipWiring/main/lib/Silicon/Chip/svg/y1_1.svg">



=head1 Hash Definitions




=head2 Silicon::Chip::Wiring Definition


Wire




=head3 Output fields


=head4 X

End   x position of wire

=head4 Y

End   y position of wire

=head4 height

Height of chip

=head4 l

Level on which wore is drawn

=head4 levelX

{level}{x}{y} - available cells in X  - used cells are deleted. Normally if present the cell, if present has a positive value.  If it has a negative it is a temporary addition for the purpose of connecting the end points of the wires to the vertical vias.

=head4 levelY

{level}{x}{y} - available cells in Y

=head4 levels

Levels in use

=head4 n

Optional name

=head4 p

Path from start to finish

=head4 width

Width of chip

=head4 wires

Wires on diagram

=head4 x

Start x position of wire

=head4 y

Start y position of wire



=head1 Private Methods

=head2 newLevel($diagram, %options)

Make a new level and return its number

     Parameter  Description
  1  $diagram   Diagram
  2  %options   Options

=head2 printHash   ($x)

Print a two dimensional hash

     Parameter  Description
  1  $x         Two dimensional hash

=head2 printCells  ($diagram, $level)

Print the cells and sub cells in a diagram

     Parameter  Description
  1  $diagram   Diagram
  2  $level

=head2 svgLevel($D, $level, %options)

Draw the bus lines by level.

     Parameter  Description
  1  $D         Wiring diagram
  2  $level     Level
  3  %options   Options


=head1 Index


1 L<findShortestPath|/findShortestPath> - Find the shortest path between two points in a two dimensional image stepping only from/to adjacent marked cells.

2 L<gds2|/gds2> - Draw the wires using GDS2

3 L<length|/length> - Length of a wire in a diagram

4 L<new|/new> - New wiring diagram.

5 L<newLevel|/newLevel> - Make a new level and return its number

6 L<numberOfWires|/numberOfWires> - Number of wires in the diagram

7 L<print|/print> - Print a diagram

8 L<printCells|/printCells> - Print the cells and sub cells in a diagram

9 L<printHash|/printHash> - Print a two dimensional hash

10 L<printPath|/printPath> - Print a path as a two dimensional character image

11 L<printWire|/printWire> - Print a wire to a string

12 L<svg|/svg> - Draw the bus lines by level.

13 L<svgLevel|/svgLevel> - Draw the bus lines by level.

14 L<totalLength|/totalLength> - Total length of wires

15 L<wire|/wire> - New wire on a wiring diagram.

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
clearFolder(q(gds), 99);                                                        # Clear the output gds folder
my $start = time;
eval "use Test::More";
eval "Test::More->builder->output('/dev/null')" unless $ENV{GITHUB_ACTIONS};
eval {goto latest}                              unless $ENV{GITHUB_ACTIONS};;

my sub  ok($)        {!$_[0] and confess; &ok( $_[0])}
my sub nok($)        {&ok(!$_[0])}

# Tests

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

#latest:;
if (1)                                                                          #TfindShortestPath
 {my %i = splitSplit(<<END);
111111
000111
000011
111111
END
  my $p = [findShortestPath(undef, \%i, \%i, [0, 0], [0,3])];
  is_deeply(printPath($p), <<END);
S0001
....1
....1
F0000
END
 }

#latest:;
if (1)                                                                          #
 {my %i = splitSplit(<<END);
1111111111
1001110001
0100110001
1111110001
END
  my $p = [findShortestPath(undef, \%i, \%i, [0, 0], [0,3])];
  is_deeply(printPath($p), <<END);
S0001
....1
....1
F0000
END
 }

#latest:;
if (1)                                                                          #
 {my %i = splitSplit(<<END);
111111111111
111111111111
111111111111
111111111111
111100001111
111100001111
111100001111
111100001111
111111111111
111111111111
111111111111
111111111111
END
  my $p = [findShortestPath(undef, \%i, \%i, [3, 3], [8, 8])];
  is_deeply(printPath($p), <<END);
.........
.........
.........
...S.....
...1.....
...1.....
...1.....
...1.....
...00000F
END
 }

#latest:;
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
  is_deeply([findShortestPath(undef, \%ix, \%iy, [0, 0], [0,8])], [[0, 0, 0],   [1, 0, 0],   [2, 0, 0],   [3, 0, 0],   [4, 0, 0],   [5, 0, 0],   [6, 0, 0],   [7, 0, 0],   [8, 0, 0],   [9, 0, 0],   [10, 0, 0],   [11, 0, 0],   [12, 0, 0],   [13, 0, 0],   [14, 0, 0],   [15, 0, 0],   [16, 0, 0],   [17, 0, 0],   [18, 0, 0],   [19, 0, 0],   [20, 0, 0],   [21, 0, 0],   [22, 0, 0],   [23, 0, 0],   [24, 0, 0],   [25, 0, 0],   [26, 0, 0],   [27, 0, 0],   [28, 0, 0],   [29, 0, 0],   [30, 0, 0],   [31, 0, 0],   [32, 0, 0],   [33, 0, 0],   [34, 0, 0],   [35, 0, 0],   [36, 0, 0],   [37, 0, 0],   [38, 0, 0],   [39, 0, 0],   [40, 0, 0],   [41, 0, 0],   [42, 0, 0],   [43, 0, 0],   [44, 0, 0],   [45, 0, 0],   [46, 0, 0],   [47, 0, 0],   [48, 0, 0],   [49, 0, 0],   [50, 0, 0],   [51, 0, 0],   [52, 0, 0],   [53, 0, 0],   [54, 0, 0],   [55, 0, 0],   [56, 0, 0],   [57, 0, 0],   [58, 0, 0],   [59, 0, 0],   [60, 0, 0],   [61, 0, 0],   [62, 0, 0],   [63, 0, 0],   [64, 0, 0],   [65, 0, 0],   [66, 0, 0],   [67, 0, 0],   [68, 0, 0],   [69, 0, 0],   [70, 0, 0],   [71, 0, 0],   [72, 0, 0],   [73, 0, 0],   [74, 0, 0],   [75, 0, 0],   [76, 0, 0],   [77, 0, 0],   [78, 0, 1],   [78, 1, 1],   [78, 2, 0],   [77, 2, 0],   [76, 2, 0],   [75, 2, 0],   [74, 2, 0],   [73, 2, 0],   [72, 2, 0],   [71, 2, 0],   [70, 2, 0],   [69, 2, 0],   [68, 2, 0],   [67, 2, 0],   [66, 2, 0],   [65, 2, 0],   [64, 2, 0],   [63, 2, 0],   [62, 2, 0],   [61, 2, 0],   [60, 2, 0],   [59, 2, 0],   [58, 2, 0],   [57, 2, 0],   [56, 2, 0],   [55, 2, 0],   [54, 2, 0],   [53, 2, 0],   [52, 2, 0],   [51, 2, 0],   [50, 2, 0],   [49, 2, 0],   [48, 2, 0],   [47, 2, 0],   [46, 2, 0],   [45, 2, 0],   [44, 2, 0],   [43, 2, 0],   [42, 2, 0],   [41, 2, 0],   [40, 2, 0],   [39, 2, 0],   [38, 2, 0],   [37, 2, 0],   [36, 2, 0],   [35, 2, 0],   [34, 2, 0],   [33, 2, 0],   [32, 2, 0],   [31, 2, 0],   [30, 2, 0],   [29, 2, 0],   [28, 2, 0],   [27, 2, 0],   [26, 2, 0],   [25, 2, 0],   [24, 2, 0],   [23, 2, 0],   [22, 2, 0],   [21, 2, 0],   [20, 2, 0],   [19, 2, 0],   [18, 2, 0],   [17, 2, 0],   [16, 2, 0],   [15, 2, 0],   [14, 2, 0],   [13, 2, 0],   [12, 2, 0],   [11, 2, 0],   [10, 2, 0],   [9, 2, 0],   [8, 2, 0],   [7, 2, 0],   [6, 2, 0],   [5, 2, 0],   [4, 2, 0],   [3, 2, 0],   [2, 2, 1],   [2, 3, 1],   [2, 4, 0],   [3, 4, 0],   [4, 4, 0],   [5, 4, 0],   [6, 4, 0],   [7, 4, 0],   [8, 4, 0],   [9, 4, 0],   [10, 4, 0],   [11, 4, 0],   [12, 4, 0],   [13, 4, 0],   [14, 4, 0],   [15, 4, 0],   [16, 4, 0],   [17, 4, 0],   [18, 4, 0],   [19, 4, 0],   [20, 4, 0],   [21, 4, 0],   [22, 4, 0],   [23, 4, 0],   [24, 4, 0],   [25, 4, 0],   [26, 4, 0],   [27, 4, 0],   [28, 4, 0],   [29, 4, 0],   [30, 4, 0],   [31, 4, 0],   [32, 4, 0],   [33, 4, 0],   [34, 4, 0],   [35, 4, 0],   [36, 4, 0],   [37, 4, 0],   [38, 4, 0],   [39, 4, 0],   [40, 4, 0],   [41, 4, 0],   [42, 4, 0],   [43, 4, 0],   [44, 4, 0],   [45, 4, 0],   [46, 4, 0],   [47, 4, 0],   [48, 4, 0],   [49, 4, 0],   [50, 4, 0],   [51, 4, 0],   [52, 4, 0],   [53, 4, 0],   [54, 4, 0],   [55, 4, 0],   [56, 4, 0],   [57, 4, 0],   [58, 4, 0],   [59, 4, 0],   [60, 4, 0],   [61, 4, 0],   [62, 4, 0],   [63, 4, 0],   [64, 4, 0],   [65, 4, 0],   [66, 4, 0],   [67, 4, 0],   [68, 4, 0],   [69, 4, 0],   [70, 4, 0],   [71, 4, 0],   [72, 4, 0],   [73, 4, 0],   [74, 4, 0],   [75, 4, 0],   [76, 4, 0],   [77, 4, 0],   [78, 4, 1],   [78, 5, 1],   [78, 6, 0],   [77, 6, 0],   [76, 6, 0],   [75, 6, 0],   [74, 6, 0],   [73, 6, 0],   [72, 6, 0],   [71, 6, 0],   [70, 6, 0],   [69, 6, 0],   [68, 6, 0],   [67, 6, 0],   [66, 6, 0],   [65, 6, 0],   [64, 6, 0],   [63, 6, 0],   [62, 6, 0],   [61, 6, 0],   [60, 6, 0],   [59, 6, 0],   [58, 6, 0],   [57, 6, 0],   [56, 6, 0],   [55, 6, 0],   [54, 6, 0],   [53, 6, 0],   [52, 6, 0],   [51, 6, 0],   [50, 6, 0],   [49, 6, 0],   [48, 6, 0],   [47, 6, 0],   [46, 6, 0],   [45, 6, 0],   [44, 6, 0],   [43, 6, 0],   [42, 6, 0],   [41, 6, 0],   [40, 6, 0],   [39, 6, 0],   [38, 6, 0],   [37, 6, 0],   [36, 6, 0],   [35, 6, 0],   [34, 6, 0],   [33, 6, 0],   [32, 6, 0],   [31, 6, 0],   [30, 6, 0],   [29, 6, 0],   [28, 6, 0],   [27, 6, 0],   [26, 6, 0],   [25, 6, 0],   [24, 6, 0],   [23, 6, 0],   [22, 6, 0],   [21, 6, 0],   [20, 6, 0],   [19, 6, 0],   [18, 6, 0],   [17, 6, 0],   [16, 6, 0],   [15, 6, 0],   [14, 6, 0],   [13, 6, 0],   [12, 6, 0],   [11, 6, 0],   [10, 6, 0],   [9, 6, 0],   [8, 6, 0],   [7, 6, 0],   [6, 6, 0],   [5, 6, 0],   [4, 6, 0],   [3, 6, 0],   [2, 6, 1],   [2, 7, 1],   [2, 8, 0],   [1, 8, 0],   [0, 8]]);
 }

#latest:;
if (1)                                                                          #
 {my      $d = new(width=>3, height=>2);
  is_deeply($d->height, 2);
  is_deeply($d->width,  3);
 }

#latest:;
if (1)                                                                          #TnumberOfWires
 {my      $d = new(width=>3, height=>2);
  my $w = $d->wire(x=>1, y=>1, X=>2, Y=>1, n=>'a');
  is_deeply($d->numberOfWires, 1);
  is_deeply(printPath($w->p), <<END);
.........
.........
.........
.........
....S000F
END
  $d->gds2(svg=>q(x1));
 }

#latest:;
if (1)                                                                          #Tsvg #Tgds2 #Tlength
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
  $d->gds2(svg=>q(y1));
 }

#latest:;
if (1)                                                                          #TprintPath
 {my      $d = new(width=>2, height=>2);
  my $a = $d->wire(x=>1, y=>1, X=>2, Y=>2, n=>'a');
  is_deeply(printPath($a->p), <<END);
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

#latest:;
if (1)                                                                          #Tprint #TprintWire #TprintCode #TprintInOrder
 {my      $d = new(width=>2, height=>2);
  my $a = $d->wire(x=>1, y=>1, X=>2, Y=>1, n=>'a');
  my $b = $d->wire(x=>1, y=>2, X=>2, Y=>2, n=>'b');
  is_deeply($d->print, <<END);
Length: 10
   x,   y      X,   Y   L  Name    Path
   1,   1      2,   1   1  a       4,4,0  5,4,0  6,4,0  7,4,0  8,4
   1,   2      2,   2   1  b       4,8,0  5,8,0  6,8,0  7,8,0  8,8
END
  is_deeply($d->printWire($a), "   1,   1      2,   1   1  a       4,4,0  5,4,0  6,4,0  7,4,0  8,4");
  is_deeply($d->printCode,, <<END);
\$d->wire(x=> 1, y=> 1, X=> 2, Y=> 1);
\$d->wire(x=> 1, y=> 2, X=> 2, Y=> 2);
END
  is_deeply($d->printInOrder, <<END);
Length: 10
   x,   y      X,   Y   L  Name    Path
   1,   1      2,   1   1  a       4,4,0  5,4,0  6,4,0  7,4,0  8,4
   1,   2      2,   2   1  b       4,8,0  5,8,0  6,8,0  7,8,0  8,8
END
 }

#latest:;
if (1)                                                                          #Tnew #Twire #TtotalLength
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
  is_deeply($d->totalLength, 119);
  is_deeply($d->levels, 2);

  is_deeply($d->printInOrder, <<END);
Length: 119
   x,   y      X,   Y   L  Name    Path
   0,   0      3,   0   2  g       0,0,1  0,1,1  0,2,0  1,2,0  2,2,0  3,2,0  4,2,0  5,2,0  6,2,0  7,2,0  8,2,0  9,2,0  10,2,0  11,2,0  12,2,1  12,1,1  12,0
   0,   1      2,   1   1  a       0,4,1  0,3,1  0,2,0  1,2,0  2,2,0  3,2,0  4,2,0  5,2,0  6,2,0  7,2,0  8,2,1  8,3,1  8,4
   0,   2      1,   1   1  e       0,8,1  0,7,1  0,6,0  1,6,0  2,6,0  3,6,0  4,6,1  4,5,1  4,4
   0,   3      4,   0   1  f       0,12,1  0,11,1  0,10,0  1,10,0  2,10,0  3,10,0  4,10,0  5,10,0  6,10,0  7,10,0  8,10,0  9,10,0  10,10,0  11,10,0  12,10,0  13,10,0  14,10,1  14,9,1  14,8,1  14,7,1  14,6,1  14,5,1  14,4,1  14,3,1  14,2,1  14,1,1  14,0,0  15,0,0  16,0
   1,   0      1,   2   1  b       4,0,0  3,0,0  2,0,1  2,1,1  2,2,1  2,3,1  2,4,1  2,5,1  2,6,1  2,7,1  2,8,0  3,8,0  4,8
   1,   3      3,   0   1  F       4,12,0  5,12,0  6,12,1  6,13,1  6,14,0  7,14,0  8,14,0  9,14,0  10,14,1  10,13,1  10,12,1  10,11,1  10,10,1  10,9,1  10,8,1  10,7,1  10,6,1  10,5,1  10,4,1  10,3,1  10,2,1  10,1,1  10,0,0  11,0,0  12,0
   2,   0      2,   2   1  c       8,0,0  7,0,0  6,0,1  6,1,1  6,2,1  6,3,1  6,4,1  6,5,1  6,6,1  6,7,1  6,8,0  7,8,0  8,8
END

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

#    Original   Collapse
#    012345678  012345678
#  0
#  1
#  2 000000001  0.......1
#  3 1       1  .       .
#  4 1       1  0       1

#latest:;
if (1)                                                                          #TcollapsePath
 {my @p = collapsePath([
  [0, 4, 1],
  [0, 3, 1],
  [0, 2, 0],
  [1, 2, 0],
  [2, 2, 0],
  [3, 2, 0],
  [4, 2, 0],
  [5, 2, 0],
  [6, 2, 0],
  [7, 2, 0],
  [8, 2, 1],
  [8, 3, 1],
  [8, 4]]);
  is_deeply([@p], [
   [[0, 4, 1], [0, 2, 0], 0],
   [[1, 2, 0], [8, 2, 1], 0],
   [[8, 3, 1], [8, 4],    0]]);
 }

#latest:;
if (1)
 {my @p = collapsePath([
  [0, 12, 1],
  [0, 11, 1],
  [0, 10, 0],
  [1, 10, 0],
  [2, 10, 0],
  [3, 10, 0],
  [4, 10, 0],
  [5, 10, 0],
  [6, 10, 0],
  [7, 10, 0],
  [8, 10, 0],
  [9, 10, 0],
  [10, 10, 0],
  [11, 10, 0],
  [12, 10, 0],
  [13, 10, 0],
  [14, 10, 1],
  [14, 9, 1],
  [14, 8, 1],
  [14, 7, 1],
  [14, 6, 1],
  [14, 5, 1],
  [14, 4, 1],
  [14, 3, 1],
  [14, 2, 1],
  [14, 1, 1],
  [14, 0, 0],
  [15, 0, 0],
  [16, 0]]);
  is_deeply([@p], [
  [[0, 12, 1], [ 0, 10, 0], 0],
  [[1, 10, 0], [14, 10, 1], 0],
  [[14, 9, 1], [14,  0, 0], 1],
  [[15, 0, 0], [16,  0],    1],
   ]);
 }

#latest:;
if (1)                                                                          #Tnew #Twire #TtotalLength
 {my $d = new(width=>90, height=>20);
     $d->wire(x=> 9, y=>14, X=>50, Y=> 5);
     $d->wire(x=>13, y=> 5, X=>50, Y=>12);
     $d->wire(x=>13, y=> 8, X=>54, Y=> 5);
     $d->wire(x=> 5, y=>11, X=>42, Y=> 5);
     $d->wire(x=> 9, y=> 2, X=>42, Y=>12);
     $d->wire(x=>13, y=> 2, X=>50, Y=> 7);
     $d->wire(x=>13, y=>11, X=>54, Y=>10);
     $d->wire(x=>13, y=>14, X=>54, Y=>15);
     $d->wire(x=> 5, y=>14, X=>42, Y=>10);
     $d->wire(x=>17, y=> 2, X=>58, Y=> 2);
     $d->wire(x=> 9, y=> 8, X=>46, Y=> 7);
     $d->wire(x=> 9, y=>11, X=>46, Y=>12);
     $d->wire(x=> 5, y=> 8, X=>38, Y=>12);
     $d->wire(x=> 9, y=> 5, X=>46, Y=> 5);
     $d->wire(x=> 5, y=> 5, X=>38, Y=> 7);
     $d->wire(x=> 5, y=> 2, X=>38, Y=> 2);
     $d->wire(x=>37, y=> 7, X=>58, Y=> 4);
     $d->wire(x=>41, y=> 7, X=>62, Y=> 4);
     $d->wire(x=>33, y=> 9, X=>50, Y=> 3);
     $d->wire(x=>41, y=>12, X=>62, Y=>10);
     $d->wire(x=>45, y=> 2, X=>62, Y=> 8);
     $d->wire(x=>33, y=>14, X=>50, Y=> 9);
     $d->wire(x=>45, y=> 7, X=>62, Y=>12);
     $d->wire(x=>37, y=> 4, X=>54, Y=> 8);
     $d->wire(x=>37, y=> 9, X=>54, Y=>13);
     $d->wire(x=>41, y=> 2, X=>62, Y=> 2);
     $d->wire(x=>33, y=> 2, X=>46, Y=> 9);
     $d->wire(x=>33, y=> 7, X=>46, Y=>14);
     $d->wire(x=>49, y=> 7, X=>66, Y=> 4);
     $d->wire(x=>33, y=>12, X=>50, Y=>14);
     $d->wire(x=>45, y=>12, X=>62, Y=>14);
     $d->wire(x=>49, y=>12, X=>66, Y=>10);
     $d->wire(x=>53, y=> 2, X=>66, Y=> 8);
     $d->wire(x=>37, y=> 2, X=>54, Y=> 3);
     $d->wire(x=>53, y=> 7, X=>66, Y=>12);
     $d->wire(x=>29, y=> 7, X=>42, Y=> 3);
     $d->wire(x=>29, y=>12, X=>42, Y=> 8);
     $d->wire(x=>49, y=> 2, X=>66, Y=> 2);
     $d->wire(x=>57, y=> 7, X=>70, Y=> 4);
     $d->wire(x=>53, y=>12, X=>66, Y=>14);
     $d->wire(x=>57, y=>12, X=>70, Y=>10);
     $d->wire(x=>61, y=> 2, X=>70, Y=> 8);
     $d->wire(x=>17, y=>14, X=>22, Y=> 5);
     $d->wire(x=>25, y=> 2, X=>34, Y=> 7);
     $d->wire(x=>29, y=> 4, X=>38, Y=> 9);
     $d->wire(x=>29, y=> 9, X=>38, Y=>14);
     $d->wire(x=>33, y=> 4, X=>46, Y=> 3);
     $d->wire(x=>21, y=>14, X=>30, Y=>10);
     $d->wire(x=>29, y=>14, X=>42, Y=>14);
     $d->wire(x=>57, y=> 2, X=>70, Y=> 2);
     $d->wire(x=>65, y=> 7, X=>74, Y=> 4);
     $d->wire(x=>21, y=> 7, X=>30, Y=> 5);
     $d->wire(x=>29, y=> 2, X=>38, Y=> 4);
     $d->wire(x=>65, y=>12, X=>74, Y=>10);
     $d->wire(x=>69, y=> 2, X=>74, Y=> 8);
     $d->wire(x=>21, y=> 2, X=>26, Y=> 7);
     $d->wire(x=>25, y=> 4, X=>34, Y=> 5);
     $d->wire(x=>69, y=> 7, X=>74, Y=>12);
     $d->wire(x=>81, y=> 2, X=>82, Y=>11);
     $d->wire(x=>21, y=>12, X=>30, Y=>12);
     $d->wire(x=>65, y=> 2, X=>74, Y=> 2);
     $d->wire(x=>21, y=> 9, X=>26, Y=>12);
     $d->wire(x=>73, y=> 7, X=>78, Y=> 4);
     $d->wire(x=>77, y=>12, X=>82, Y=> 9);
     $d->wire(x=>69, y=>12, X=>74, Y=>14);
     $d->wire(x=>21, y=> 4, X=>26, Y=> 5);
     $d->wire(x=>77, y=> 7, X=>82, Y=> 6, debug=>1);
 }

&done_testing;
finish: 1
