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
      return if $px < 0 or $py < 0 or $px >= $w*4 or $py >= $h*4;               # Sub cell out of range
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
    fillInAroundVia($_, $x, $y, $l, 22) for $lx, $ly;                            # Add metal around via so it can connect to the crossbars
    fillInAroundVia($_, $X, $Y, $l, 22) for $lx, $ly;
    my @p = $diagram->findShortestPath($lx, $ly, [$x*4, $y*4], [$X*4, $Y*4]);
    if (@p and !@P || @p < @P)                                                  # Shorter path on this level
     {@P = @p;
      $w->l = $l;
     }
    fillInAroundVia($_, $x, $y, $l, undef) for $lx, $ly;                        # Remove metal
    fillInAroundVia($_, $X, $Y, $l, undef) for $lx, $ly;
   }

  for my $l(1..$diagram->levels)                                                # Find best level to place wire
   {pathOnLevel($l);
   }

  if (!@P)                                                                      # Have to create a new level for this wire
   {my $l = $diagram->newLevel;
    pathOnLevel($l);
   }
  @P or confess <<"END" =~ s/\n(.)/ $1/gsr;                                     # The new layer should always resolve thos problem, but just in case.
Cannot connect [$x, $y] to [$X, $Y]
END

  if (@P)
   {my $l = $w->l;
    my $lx = $diagram->levelX->{$l};                                            # X cells available on this level
    my $ly = $diagram->levelY->{$l};                                            # Y cells available on this level
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

sub findShortestPath($$$$$)                                                     # Find the shortest path between two points in a two dimensional image stepping only from/to adjacent marked cells. The permissible steps are given in two imahes, one for x steps and one for y steps.
 {my ($diagram, $imageX, $imageY, $start, $finish) = @_;                        # Diagram, ImageX{x}{y}, ImageY{x}{y}, start point, finish point
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
       {my sub search($$)                                                       # Search from a point in the current frontier
         {my ($x, $y) = @_;                                                     # Point to test
          if ($ix{$x}{$y} || $iy{$x}{$y} and !exists $b{$x}{$y})                # Located a new unclassified cell
           {$d{$d}{$x}{$y} = $n{$x}{$y} = $b{$x}{$y} = $d;                      # Set depth for cell and record is as being at that depth
           }
         }
        search($x-1, $y);   search($x+1, $y);                                   # Search for a step in x
        search($x,   $y-1); search($x,   $y+1);                                 # Search for a step in y
       }
     }
    %o = %n;                                                                    # The new frontier becomes the settled fontoer
   }

  return () unless my $N = $b{$X}{$Y};                                          # Return empty list if there is no path from the start to the finish
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
  $q < $p ? @$Q : @$P                                                           # Path with least changes of direction
 }

#D1 Visualize                                                                   # Visualize a Silicon chip wiring diagrams

my sub wireHeader()                                                             #P Wire header
 {"   x,   y      X,   Y   L  Name    Path";
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

sub printHash($)                                                                # Print a two dimensional hash
 {my ($x) = @_;                                                                 # Two dimensional hash
  my %x = $x->%*;

  my $w; my $h;
  for   my $x(sort keys %x)                                                     # Size of image
   {for my $y(sort keys $x{$x}->%*)
     {$w = maximum($w, $x);
      $h = maximum($h, $y);
     }
   }

  my @s = (' ' x (4+$w)) x (4+$h);                                              # Empty image
  for   my $x(sort keys %x)                                                     # Load image
   {for my $y(sort keys $x{$x}->%*)
     {substr($s[$y], $x, 1) = substr("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ", $x{$x}{$y}, 1);
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

sub svgLevel($$%)                                                               #P Draw the bus lines by level.
 {my ($D, $level, %options) = @_;                                               # Wiring diagram, level, options

  my @defaults = (defaults=>                                                    # Default values
   {stroke_width => 0.5,
    opacity      => 0.75,
   });

  my $svg = Svg::Simple::new(@defaults, %options, grid=>debugMask ? 1 : 0);     # Draw each wire via Svg. Grid set to 1 produces a grid that can be helpful debugging layout problems

  for my $w($D->wires->@*)                                                      # Each wire in X
   {my ($l, $p) = @$w{qw(l p)};                                                 # Level and path
    next unless $l == $level;                                                   # Draw the specified level
    for my $i(keys @$p)                                                         # Index path
     {my $q = $$p[$i];                                                          # Element of path
      my ($x, $y) = @$q;
      $x /= 4; $y /= 4;                                                         # Scale
      my $c = q(blue);
      $c = 'darkGreen' if $i == 0;
      $c = 'darkRed'   if $i == $#$p;
      $svg->rect(x=>$x, y=>$y, width=>1/4, height=>1/4, fill=>$c, opacity=>1);
     }
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

  my sub via($$$)                                                               # Draw a vertical connector
   {my ($x, $y, $l) = @_;                                                       # Options
    $g->printBoundary(-layer=>$l*$Nl+2, -xy=>[$x-$s,$y-$s, $x+$s,$y-$s, $x+$s,$y+$s, $x-$s,$y+$s]); # Vertical connector
   }

  #say STDERR wireHeader;
  for my $j(keys @w)                                                            # Layout each wire
   {my $w = $w[$j];
    my ($x, $y, $X, $Y, $l, $p) = @$w{qw(x y X Y l p)};
    #say STDERR $diagram->printWire($w);

    for my $i(1..$#$p-1)                                                        # All along the path
     {my $q = $$p[$i];                                                          # All along the path
      my ($x, $y, $s) = @$q;                                                    # Position, direction
      $x /= 4; $y /= 4;                                                         # Normalize positions of sub cells

      my $L = $l * $Nl;                                                         # Sub level in wiring level
         $L += 1 if $s == 0;
         $L += 3 if $s != 0;
      $g->printBoundary(-layer=>$L, -xy=>[$x,$y, $x+$S,$y, $x+$S,$y+$S, $x,$y+$S]); # Fill in cell
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
clearFolder(q(gds), 99);                                                        # Clear the output gds folder
my $start = time;
eval "use Test::More";
eval "Test::More->builder->output('/dev/null')" if -e q(/home/phil/);
eval {goto latest} if -e q(/home/phil/);

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
  is_deeply($d->numberOfWires($w), 1);
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
 {my      $d = new(width=>2, height=>3);
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
#svg=>q(y1_1)
 }

#latest:;
if (1)                                                                          #TprintPath
 {my      $d = new(width=>3, height=>3);
  my $w = $d->wire(x=>1, y=>1, X=>2, Y=>2, n=>'c');
  is_deeply(printPath($w->p), <<END);
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
 }

#latest:;
if (1)                                                                          #Tnew #Twire
 {my      $d = new(width=>4, height=>3);
  my $a = $d->wire(x=>0, y=>1, X=>2, Y=>1, n=>'a');
  my $b = $d->wire(x=>1, y=>0, X=>1, Y=>2, n=>'b');
  my $c = $d->wire(x=>2, y=>0, X=>2, Y=>2, n=>'c');
  my $e = $d->wire(x=>0, y=>2, X=>1, Y=>1, n=>'e');

  is_deeply($d->levels, 1);
  my $f = $d->wire(x=>0, y=>0, X=>3, Y=>0, n=>'f');
  is_deeply($d->levels, 2);
  #say STDERR printPath($f->p);


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
S...........F
1...........1
0000000000001
END
  $d->svg (svg=>q(xy2));
  $d->gds2(svg=>q(xy2));
#svg=>q(xy2_1)
#svg=>q(xy2_2)
 }


&done_testing;
finish: 1
