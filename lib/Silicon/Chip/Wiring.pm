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
use Carp qw(confess cluck);
use Data::Dump qw(dump);
use Data::Table::Text qw(:all);
use Svg::Simple;
use GDS2;

makeDieConfess;

sub pixelsPerCell  {4}                                                          # Pixels per cell
sub crossBarOffset {2}                                                          # Offset of crossbars in each cell
sub svgGrid        {1}                                                          # Adds a grid to each svg image

#D1 Construct                                                                   # Create a Silicon chip wiring diagram on one or more levels as necessary to make the connections requested.

sub new(%)                                                                      # New wiring diagram.
 {my (%options) = @_;                                                           # Options

  my $d = genHash(__PACKAGE__,                                                  # Wiring diagram
    options=> \%options,                                                        # Creation options
    log    => $options{log},                                                    # Log activity if true
    width  => $options{width},                                                  # Width of chip,  if not specified an estimated value will be used
    height => $options{height},                                                 # Height of chip, if not specified an estimated value will be used
    wires  => [],                                                               # Wires on diagram
    levels => 0,                                                                # Levels in use
    levelX => {},                                                               # {level}{x}{y} - available cells in X  - used cells are deleted. Normally if present the cell, if present has a positive value.  If it has a negative it is a temporary addition for the purpose of connecting the end points of the wires to the vertical vias.
    levelY => {},                                                               # {level}{x}{y} - available cells in Y
    gsx    => $options{gsx} // 1,                                               # Gate scale in x
    gsy    => $options{gsy} // 1,                                               # Gate scale in y
   );
  $d
 }

sub wire($$$$$%)                                                                # New wire on a wiring diagram.
 {my ($diagram, $x, $y, $X, $Y, %options) = @_;                                 # Diagram, start x, start y, end x, end y, options

  defined($x) or confess "x";
  defined($y) or confess "y";
  defined($X) or confess "X";
  defined($Y) or confess "Y";
  $x == $X and $y == $Y and confess "Start and end of connection are in the same cell";
  lll "Wire", scalar($diagram->wires->@*) if $diagram->options->{debug};

  my $cx = $diagram->gsx * pixelsPerCell;
  my $cy = $diagram->gsy * pixelsPerCell;
  $x % $cx and confess "Start  x $x must be divisible by $cx";
  $y % $cy and confess "Start  y $y must be divisible by $cy";
  $X % $cx and confess "Finish x $X must be divisible by $cx";
  $Y % $cy and confess "Finish y $Y must be divisible by $cy";


  my $w = genHash(__PACKAGE__,                                                  # Wire
    x => $x,                                                                    # Start x position of wire
    X => $X,                                                                    # End   x position of wire
    y => $y,                                                                    # Start y position of wire
    Y => $Y,                                                                    # End   y position of wire
    l => undef,                                                                 # Level on which wire is drawn
    n => $options{n}//'',                                                       # Optional name
    p => [],                                                                    # Path from start to finish
   );

  push $diagram->wires->@*, $w;                                                 # Save wire
  $w                                                                            # The wire
 }

sub segment($%)                                                                 #P New segment on wiring diagram
 {my ($diagram, %options) = @_;                                                 # Diagram, segment details from Diagram.java
  my $x = $options{x};
  my $y = $options{y};
  my $w = $options{width};
  my $h = $options{height};
  my $o = $options{onX};

  defined($x) or confess "x";
  defined($y) or confess "y";
  defined($w) or defined($h) or confess "Width or height required";

  genHash(__PACKAGE__."::Segment",                                              # Segment
    x => $x,                                                                    # Start x position of segment
    y => $y,                                                                    # Start y position of segment
    X => $x+($w//1),                                                            # Finish x position of segment
    Y => $y+($h//1),                                                            # Finish y position of segment
    w => $w,                                                                    # Width of segment or undef if on Y cross bar
    h => $h,                                                                    # Height of segment or undef if on X cross bar
    o => $o,                                                                    # On X crossbar
   );
 }

sub intersect($$$$%)                                                            #P Intersection between two adjacent segments
 {my ($diagram, $wire, $s, $S, %options) = @_;                                  # Diagram, wire, first segment, second segment, options

  ($s, $S) = ($S, $s) unless $s->w;                                             # First segment is horizontal, second one vertical
  return ($s->x,     $s->y)   if $s->x == $S->x and $s->y == $S->y;
  return ($s->X-1,   $s->y)   if $s->X == $S->X and $s->y == $S->y;
  return ($s->X-1,   $s->Y-1) if $s->X == $S->X and $s->Y == $S->Y;
  return ($s->x,     $s->Y-1) if $s->x == $S->x and $s->Y == $S->Y;
  say STDERR "Wire    = ", dump($wire);
  say STDERR "Segment1= ", dump($s);
  say STDERR "Segment2= ", dump($S);
  confess "No intersection";
 }

sub resetLevels($%)                                                             #P Reset all the levels so we can layout again
 {my ($diagram, %options) = @_;                                                 # Diagram, options

  $diagram->levels = 0;
  $diagram->levelX = {};
  $diagram->levelY = {};
  my @w = $diagram->wires->@*;
  for my $w(@w)
   {$w->l = $w->p = undef;
   }
 }

sub layout($%)                                                                  # Layout the wires using Java
 {my ($diagram, %options) = @_;                                                 # Diagram, options
  my $d   = $diagram;                                                           # Shorten name

  my @w = $d->wires->@*;
  return unless @w;                                                             # Nothing to layout

  $d->resetLevels;                                                              # Reset for new layout

  my $width; my $height;                                                        # Find width and height of diagram
  for my $w(@w)                                                                 # Each wire
   {my ($x, $y, $X, $Y) = @$w{qw(x y X Y)};
    $width  = maximum($width,  $x, $X);
    $height = maximum($height, $y, $Y);
   }

  $d->width  //= $width  + $d->gsx * pixelsPerCell - 1;                         # Update dimensions if none were supplied
  $d->height //= $height + $d->gsy * pixelsPerCell - 1;

  my $i = temporaryFile;                                                        # Specification of wires to be made
  my $o = temporaryFile;                                                        # Details of connections made
  my $j = q(Diagram.java);                                                      # Code to produce wiring diagram
  my $c = pixelsPerCell;                                                        # Pixels per cell

  my $gsx = $diagram->gsx;                                                      # Gate scale x
  my $gsy = $diagram->gsy;                                                      # Gate scale y

  owf($i, join "\n", $d->width, $d->height, $gsx, $gsy, scalar(@w),             # Diagram details and connections desired ready for Java
    map {($_->x, $_->y, $_->X, $_->Y)} @w);                                     # Start and end of each wire

  owf($j, $diagram->java(%options));                                            # Run code to produce wiring diagram
  my $r = qx(java $j < $i > $o);
  say STDERR $r if $r =~ m(\S);

  my @o = map {eval $_} readFile $o;                                            # Read wiring diagram
  @o == @w or confess "Length mismatch";
  unlink $i, $o, $j;

  for my $i(keys @w)                                                            # Parse wiring diagram
   {my $w = $w[$i];
    my $o = $o[$i];
    $w->l = $$o[0];
    my @s = $$o[1]->@*;
    for my $s(@s)                                                               # Load segments
     {my $t = $d->segment(%$s);
      push $w->p->@*, $t;
     }
   }

  $d->levels = maximum map {$_->l} $d->wires->@*;                               # Number of levels
 }

sub numberOfWires($%)                                                           # Number of wires in the diagram
 {my ($D, %options) = @_;                                                       # Diagram, options
  scalar $D->wires->@*
 }

sub length($$)                                                                  # Length of a wire in a diagram
 {my ($D, $w) = @_;                                                             # Diagram, wire
  my $l = 0;
  for my $s($w->p->@*)                                                          # Length of each segment
   {$l += ($s->w // $s->h) - 1;                                                 # Account for overlap
   }
  ++$l;                                                                         # The first segment does not overlap
 }

sub totalLength($)                                                              # Total length of wires
 {my ($d) = @_;                                                                 # Diagram
  my @w = $d->wires->@*;
  my $l = 0; $l += $d->length($_) for @w;                                       # Add length of each wire
  $l
 }

my sub distance($$$$)                                                           # Manhattan distance between two points
 {my ($x, $y, $X, $Y) = @_;                                                     # Start x, start y, end x, end y
  abs($X - $x) + abs($Y - $y)
 }

#D1 Shortest Path                                                               # Find the shortest path using compiled code

sub java($%)                                                                    #P Using Java as it is faster than Perl to layout the connections
 {my ($diagram, %options) = @_;                                                 # Options
  my $pixelsPerCell  = pixelsPerCell;
  my $crossBarOffset = crossBarOffset;
  my $j              = &loadJava;
  $j =~  s(pixelsPerCell = 4)  (pixelsPerCell = $pixelsPerCell)s;
  $j =~ s(crossBarOffset = 4) (crossBarOffset = $crossBarOffset)s;
  $j
 }

sub loadJava()                                                                  #P Load java
 {return readFile q(/home/phil/perl/cpan/SiliconChipWiring/java/Diagram.java);
   <<END
END
 }

#D1 Visualize                                                                   # Visualize a Silicon chip wiring diagrams

my sub wireHeader()                                                             #P Wire header
 {"   x,   y      X,   Y   L  Name     Path";
 }

sub printCode($%)                                                               # Print code to create a diagram
 {my ($d, %options) = @_;                                                       # Drawing, options
  my @t;
  push @t, sprintf "Silicon::Chip::Wiring::new(width=>%d, height=>%d);", $d->width//0, $d->height;
  for my $w($d->wires->@*)
   {my ($x, $y, $X, $Y) = @$w{qw(x y X Y)};
    push @t, sprintf "\$d->wire(%4d, %4d, %4d, %4d);", $x, $y, $X, $Y;
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
  my ($x, $y, $X, $Y, $l, $n, $P) = @$W{qw(x y X Y l n p)};
  my @p = sprintf "%4d,%4d   %4d,%4d  %2d  %-8s", $x, $y, $X, $Y, $l, $n;
  $x *= 4; $y *= 4;
  push @p, "$x,$y";
  for my $p(@$P)
   {my ($x1, $y1, $x2, $y2) = @$p{qw(x y X Y)};
    if ($x1 == $x and $y1 == $y)
     {$x = $x2 - 1; $y = $y2 - 1;
     }
    else
     {$x = $x1; $y = $y1;
     }
    push @p, "$x,$y";
   }
  join ' ', @p;
 }

sub printPath($$)                                                               # Print the path of a wire on the diagram as a two dimensional character image
 {my ($diagram, $wire) = @_;                                                    # Diagram, path
  my @p = $wire->p->@*;                                                         # Path

  my $W; my $H;
  for my $p(@p)                                                                 # Find dimensions of path
   {my ($x, $y, $w, $h) = @$p{qw(x y w h)};
    $W = maximum($W, $x+($w//1)); $H = maximum($H, $y+($h//1));
   }

  my @s = ('.' x $W) x $H;                                                      # Empty image

  for my $p(@p)                                                                 # Along the path
   {my ($x, $y, $w, $h) = @$p{qw(x y w h)};
    if (defined $w)
     {substr($s[$y], $_, 1) = '0' for $x..$x+$w-1;
     }
    else
     {substr($s[$_], $x, 1) = '1' for $y..$y+$h-1;
     }
   }
  my ($x, $y, $X, $Y) = @$wire{qw(x y X Y )};                                   # Start and finish
  substr($s[$y], $x, 1) = 'S';                                                  # Start
  substr($s[$Y], $X, 1) = 'F';                                                  # Finish
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

  my $gsx = $options{gsx} //= 1;                                                # Global scale X
  my $gsy = $options{gsy} //= 1;                                                # Global scale X

  if (defined(my $l = $options{level}))                                         # Draw the specified level
   {$D->svgLevel($l, %options);
   }
  elsif (defined(my $L = $D->levels))                                           # Draw all levels
   {my @s;
    for my $l(1..$L)
     {push @s, $D->svgLevel($l, %options);                                      # Write each level into a separate file
     }
    @s
   }
 }

my $changeColor = 0;                                                            # Alternate between the colors

my sub darkSvgColor                                                             # Generate a random dark color in hexadecimal format
 {my @r = map {int(rand 128)} 1..3;
  $r[$changeColor++ % @r] += 128;                                               # Make one component lighter

  sprintf "#%02X%02X%02X", @r;
 }

sub svgLevel($$%)                                                               #P Draw the bus lines by level.
 {my ($D, $level, %options) = @_;                                               # Wiring diagram, level, options
  my $gsx = $D->gsx;                                                            # Global scale in X
  my $gsy = $D->gsy;                                                            # Global scale in Y
  my $Nl = 4;                                                                   # Wiring layers within each level

  my @defaults = (defaults=>                                                    # Default values
   {stroke_width => 0.5,
    opacity      => 0.75,
    stroke       => "transparent",
    fill         => "transparent",
   });

  my $svg = Svg::Simple::new(@defaults, grid=>svgGrid);                         # Draw each wire via Svg. Grid set to 1 produces a grid that can be helpful debugging layout problems

  for my $w($D->wires->@*)                                                      # Each wire in X
   {my ($l, $p) = @$w{qw(l p)};                                                 # Level and path
    next unless defined($l) and $l == $level;                                   # Draw the specified level
    my @s  = @$p;                                                               # Segments along path
    my $dc = darkSvgColor;                                                      # Dark color
    my $S;                                                                      # Previous segment

    for my $i(keys @s)                                                          # Index segments
     {my $s = $s[$i];                                                           # Segment along path
      my ($x, $y, $X, $Y) = @$s{qw(x y X Y)};                                   # Start x, y, end X, Y
      my $w = $X - $x; my $h = $Y - $y;                                         # The segments are always arranged so that x < X and y < Y

      my $L = $l * $Nl + ($s[2] ? 2 : 0);                                       # Sub level in wiring level
      my $I = $l * $Nl + 1;                                                     # The insulation layer between the x and y crossbars.  We connect the x cross bars to the y cross bars through this later everytime we change direction in a wiring level.

      $svg->rect(x=>$x, y=>$y, width=>$w, height=>$h, fill=>$dc);               # Draw rectangle representing segment

      if (defined($S) and $s->o != $S->o)                                       # Change of level
       {my ($x, $y) = $D->intersect($w, $s, $S);
        $svg->rect(x=>$x + 1/3, y=>$y + 1/3, width=>1/3, height=>1/3, stroke=>"black", stroke_width=>1/48); # Show change of level
       }
      $S = $s;
     }
    $svg->rect(x=>$w->x, y=>$w->y, width=>1, height=>1, fill=>"darkGreen");     # Draw start of wire
    $svg->rect(x=>$w->X, y=>$w->Y, width=>1, height=>1, fill=>"darkRed");       # Draw end   of wire
   }

  my $t = $svg->print;                                                          # Text of svg

  if (my $f = $options{svg})                                                    # Optionally write to an svg file
   {my $F = fpe q(svg), "${f}_$level", q(svg);                                  # Write each level into a separate file
    confess "Wiring file already exists: $F\n" if -e $F;
    owf($F, $t)
   }

  $t
 }

sub gds2($%)                                                                    # Draw the wires using GDS2
 {my ($diagram, %options) = @_;                                                 # Wiring diagram, output file, options
  my $gsx = $diagram->gsx;                                                      # Global scale in X
  my $gsy = $diagram->gsy;                                                      # Global scale in Y
  my @w  = $diagram->wires->@*;                                                 # Wires
  return unless @w;                                                             # Nothing to draw

  my $gdsBlock  = $options{block};                                              # Existing GDS2 block
  my $gdsOut    = $options{svg};                                                # Write a newly created gds2 block to this file in the gds sub folder
  my $wireWidth = 1;                                                            # Width of a wire

  my $g = sub                                                                   # Draw as Graphics Design System 2 either inside an existing gds file or create a new one
   {return $gdsBlock if defined $gdsBlock;                                      # Drawing in an existing block
    createEmptyFile(my $f = fpe q(gds), $gdsOut, q(gds));                       # Make gds folder
    my $g = new GDS2(-fileName=>">$f");                                         # Draw as Graphics Design System 2
    $g->printInitLib(-name=>$gdsOut);
    $g->printBgnstr (-name=>$gdsOut);
    $g
   }->();

  my $Nl = pixelsPerCell;                                                       # Wiring layers within each level
  my $vx = $gsx * pixelsPerCell;                                                # Positions of vias in X
  my $vy = $gsy * pixelsPerCell;                                                # Positions of vias in Y

  my $width  = $diagram->width;                                                 # Width
  my $height = $diagram->height;                                                # Height

  if (defined(my $levels = $diagram->levels))                                   # Levels
   {for my $wl(1..$levels)                                                      # Vias
     {for my $l(0..$Nl-1)                                                       # Insulation, x layer, insulation, y layer
       {for   my $x(0..$width)                                                  # Gate io pins run vertically along the "vias"
         {next unless $x % $vx == 0;
          for my $y(0..$height)
           {next unless $y % $vy == 0;
            my $x1 = $x; my $y1 = $y;
            my $x2 = $x1 + $wireWidth; my $y2 = $y1 + $wireWidth;
            $g->printBoundary(-layer=>$wl*$Nl+$l, -xy=>[$x1,$y1, $x2,$y1, $x2,$y2, $x1,$y2]); # Via
           }
         }
       }
     }

    for my $x(0..$width)                                                        # Number cells
     {$g->printText(-xy=>[$x, -1/8], -string=>"$x", -font=>3, -anggle=>90);     # X coordinate
     }

    for my $y(1..$height)                                                       # Number cells
     {$g->printText(-xy=>[0, $y+$wireWidth*1.2], -string=>"$y", -font=>3);      # Y coordinate
     }

    my sub via($$$)                                                             # Draw a vertical connector. The vertical connectors are known as vias and transmit the gate inputs and outputs to the various wiring layers.
     {my ($x, $y, $l) = @_;                                                     # Options
      $g->printBoundary(-layer=>$l*$Nl+2, -xy=>[$x,$y, $x+1,$y, $x+1,$y+1, $x,$y+1]); # Vertical connector
     }

    for my $j(keys @w)                                                          # Layout each wire
     {my $w = $w[$j];                                                           # Wire
      my $l = $w->l;                                                            # Level wire is on
      my @s = $w->p->@*;                                                        # Segments making up the path
      my $S = undef;                                                            # Previous segment
      for my $i(keys @s)                                                        # Index segments
       {my $s = $s[$i];                                                         # Segment along path
        my ($x, $y, $X, $Y) = @$s{qw(x y X Y)};                                 # Start x, y, end X, Y

        my $L = $l * $Nl + ($s->o ? 0 : 2);                                     # Sub level in wiring level
        my $I = $l * $Nl + 1;                                                   # The insulation layer between the x and y crossbars.  We connect the x cross bars to the y cross bars through this later everytime we change direction in a wiring level.

        $g->printBoundary(-layer=>$L, -xy=>[$x,$y, $X,$y, $X,$Y, $x,$Y]);       # Fill in cell

        if (defined($S) and $s->o != $S->o)                                     # Change of level
         {my ($x, $y) = $diagram->intersect($w, $s, $S);
          $g->printBoundary(-layer=>$I, -xy=>[$x,$y, $x+1,$y, $x+1,$y+1, $x,$y+1]); # Step though insulation layer to connect the X crossbar to the Y crossbar.
         }
        $S = $s;
       }
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

#svg https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChipWiring/lib/Silicon/Chip/svg/

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

Wires are either one pixel wide or one pixel deep.

The minimum spacing between gate pins is 4 pixels corresponding to a gate scale
of gsx=>1 or gsy=>1

Wires are arranged in crossbars running along x or y on paired levels separated
by insulation.

We can step between the crossbars using vias located at intervals of 4*gsx in x
along the x crossbars and likewise 4*gsy in y along the y cross bars.

Vertical

The vertical arrangement of the paired levels of x and y crossbars viewed from
the side is:

  Y cross bar
  Insulation
  X cross bar
  Insulation

Horizontal

The horizontal arrangement of the paired levels of x and y crossbars viewed from
the top with gsx = gsy = 1 is:

  y   y   y   y   y
xxyxxxyxxxyxxxyxxxyx
  y   y   y   y   y
V y V y V y V y V y
  y   y   y   y   y
xxyxxxyxxxyxxxyxxxyx
  y   y   y   y   y
V y V y V y V y V y

V - vertical Via
x - X cross bar
y - Y cross bar

The horizontal arrangement of the paired levels of x and y crossbars viewed from
the top with gsx = 2 and gsy = 1 is:

  y   y   y   y   y
xxyxxxyxxxyxxxyxxxyx
  y   y   y   y   y
V y   y V y   y V y
  y   y   y   y   y
xxyxxxyxxxyxxxyxxxyx
  y   y   y   y   y
V y V y V y V y V y

V - vertical Via
x - X cross bar
y - Y cross bar

The missing vias enables more ways to connect to the existing vias at a cost of
requiring more surface area to layout a given set of gates.

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


=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChipWiring/lib/Silicon/Chip/png/xy2.png">


=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChipWiring/lib/Silicon/Chip/png/xy2_1.png">


=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChipWiring/lib/Silicon/Chip/png/xy2_2.png">


=head2 wire($diagram, $x, $y, $X, $Y, %options)

New wire on a wiring diagram.

     Parameter  Description
  1  $diagram   Diagram
  2  $x         Start x
  3  $y         Start y
  4  $X         End x
  5  $Y         End y
  6  %options   Options

B<Example:>


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


=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChipWiring/lib/Silicon/Chip/png/xy2.png">


=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChipWiring/lib/Silicon/Chip/png/xy2_1.png">


=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChipWiring/lib/Silicon/Chip/png/xy2_2.png">


=head2 layout  ($diagram, %options)

Layout the wires using Java

     Parameter  Description
  1  $diagram   Diagram
  2  %options   Options

=head2 numberOfWires   ($D, %options)

Number of wires in the diagram

     Parameter  Description
  1  $D         Diagram
  2  %options   Options

B<Example:>


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


=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChipWiring/lib/Silicon/Chip/svg/x1.svg">


=head2 length  ($D, $w)

Length of a wire in a diagram

     Parameter  Description
  1  $D         Diagram
  2  $w         Wire

B<Example:>


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


=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChipWiring/lib/Silicon/Chip/svg/y1.svg">


=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChipWiring/lib/Silicon/Chip/svg/y1_1.svg">


=head2 totalLength ($d)

Total length of wires

     Parameter  Description
  1  $d         Diagram

B<Example:>


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


=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChipWiring/lib/Silicon/Chip/png/xy2.png">


=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChipWiring/lib/Silicon/Chip/png/xy2_1.png">


=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChipWiring/lib/Silicon/Chip/png/xy2_2.png">


=head1 Shortest Path

Find the shortest path using compiled code

=head1 Visualize

Visualize a Silicon chip wiring diagrams

=head2 printCode   ($d, %options)

Print code to create a diagram

     Parameter  Description
  1  $d         Drawing
  2  %options   Options

B<Example:>


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


=head2 print   ($d, %options)

Print a diagram

     Parameter  Description
  1  $d         Drawing
  2  %options   Options

B<Example:>


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


=head2 printInOrder($d, %options)

Print a diagram

     Parameter  Description
  1  $d         Drawing
  2  %options   Options

B<Example:>


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


=head2 printWire   ($D, $W)

Print a wire to a string

     Parameter  Description
  1  $D         Drawing
  2  $W         Wire

B<Example:>


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


=head2 printPath   ($P)

Print a path as a two dimensional character image

     Parameter  Description
  1  $P         Path

B<Example:>


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


=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChipWiring/lib/Silicon/Chip/svg/xy1.svg">


=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChipWiring/lib/Silicon/Chip/svg/xy1_1.svg">


=head2 svg ($D, %options)

Draw the bus lines by level.

     Parameter  Description
  1  $D         Wiring diagram
  2  %options   Options

B<Example:>


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


=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChipWiring/lib/Silicon/Chip/svg/y1.svg">


=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChipWiring/lib/Silicon/Chip/svg/y1_1.svg">


=head2 gds2($diagram, %options)

Draw the wires using GDS2

     Parameter  Description
  1  $diagram   Wiring diagram
  2  %options   Output file

B<Example:>


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


=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChipWiring/lib/Silicon/Chip/svg/y1.svg">


=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChipWiring/lib/Silicon/Chip/svg/y1_1.svg">



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

Level on which wire is drawn

=head4 levelX

{level}{x}{y} - available cells in X  - used cells are deleted. Normally if present the cell, if present has a positive value.  If it has a negative it is a temporary addition for the purpose of connecting the end points of the wires to the vertical vias.

=head4 levelY

{level}{x}{y} - available cells in Y

=head4 levels

Levels in use

=head4 log

Log activity if true

=head4 n

Optional name

=head4 options

Creation options

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

=head2 resetLevels ($diagram, %options)

Reset all the levels so we can layout again

     Parameter  Description
  1  $diagram   Diagram
  2  %options   Options

=head2 java()

Using Java as it is faster than Perl to layout the connections


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


1 L<gds2|/gds2> - Draw the wires using GDS2

2 L<java|/java> - Using Java as it is faster than Perl to layout the connections

3 L<layout|/layout> - Layout the wires using Java

4 L<length|/length> - Length of a wire in a diagram

5 L<new|/new> - New wiring diagram.

6 L<numberOfWires|/numberOfWires> - Number of wires in the diagram

7 L<print|/print> - Print a diagram

8 L<printCells|/printCells> - Print the cells and sub cells in a diagram

9 L<printCode|/printCode> - Print code to create a diagram

10 L<printHash|/printHash> - Print a two dimensional hash

11 L<printInOrder|/printInOrder> - Print a diagram

12 L<printPath|/printPath> - Print a path as a two dimensional character image

13 L<printWire|/printWire> - Print a wire to a string

14 L<resetLevels|/resetLevels> - Reset all the levels so we can layout again

15 L<svg|/svg> - Draw the bus lines by level.

16 L<svgLevel|/svgLevel> - Draw the bus lines by level.

17 L<totalLength|/totalLength> - Total length of wires

18 L<wire|/wire> - New wire on a wiring diagram.

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

sub m4($$$$) {map{4*$_} @_}                                                     # Scale parameters by so that they start on vias

# Tests

#latest:;
if (1)                                                                          #
 {my      $d = new(width=>3, height=>2);
  is_deeply($d->height, 2);
  is_deeply($d->width,  3);
 }

#latest:;
if (1)                                                                          #TnumberOfWires
 {my      $d = new;
  my $w = $d->wire(m4(1, 1, 2, 1), n=>'a');
          $d->layout;

  is_deeply($d->numberOfWires, 1);
  is_deeply($d->printPath($w), <<END);
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
 {my      $d = new;
  my $w = $d->wire(m4(1, 1, 1, 2), n=>'b');
          $d->layout;
  is_deeply($d->length($w), 5);
  is_deeply($d->printPath($w), <<END);
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
 {my      $d = new;
  my $a = $d->wire(m4(1, 1, 2, 2), n=>'a');
          $d->layout;
  is_deeply($d->printPath($a), <<END);
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
 {my      $d = new;
  my $a = $d->wire(m4(1, 1, 2, 1), n=>'a');
  my $b = $d->wire(m4(1, 2, 2, 2), n=>'b');
          $d->layout;
  is_deeply($d->printWire($a), '   4,   4      8,   4   1  a        16,16 4,4');
  #say STDERR $d->print; exit;
  is_deeply($d->print, <<END);
Length: 10
   x,   y      X,   Y   L  Name     Path
   4,   4      8,   4   1  a        16,16 4,4
   4,   8      8,   8   1  b        16,32 4,8
END

  #say STDERR $d->printCode; exit;
  is_deeply($d->printCode, <<'END');
Silicon::Chip::Wiring::new(width=>12, height=>12);
$d->wire(   4,    4,    8,    4);
$d->wire(   4,    8,    8,    8);
END

  #say STDERR $d->printInOrder; exit;
  is_deeply($d->printInOrder, <<END);
Length: 10
   x,   y      X,   Y   L  Name     Path
   4,   4      8,   4   1  a        16,16 4,4
   4,   8      8,   8   1  b        16,32 4,8
END
 }

#latest:;
if (1)                                                                          #Tnew #Twire #TtotalLength
 {my      $d = new;
  my $a = $d->wire(m4(0, 1, 2, 1), n=>'a');
          $d->layout;

  #say STDERR $d->print; exit;
  is_deeply($d->print, <<END);
Length: 13
   x,   y      X,   Y   L  Name     Path
   0,   4      8,   4   1  a        0,16 0,2 8,2 8,4
END

  is_deeply($d->printPath($a), <<END);
.........
.........
000000001
1.......1
S.......F
END
 }

#latest:;
if (1)                                                                          #
 {my      $d = new;
  my $b = $d->wire(m4(1, 0, 1, 2), n=>'b');
          $d->layout;

  #say STDERR $d->printInOrder; exit;
  is_deeply($d->print, <<END);
Length: 13
   x,   y      X,   Y   L  Name     Path
   4,   0      4,   8   1  b        16,0 2,0 2,8 4,8
END

  is_deeply($d->printPath($b), <<END);
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
 }

#latest:;
if (1)                                                                          #
 {my      $d = new;
  my $c = $d->wire(m4(2, 0, 2, 2), n=>'c');
          $d->layout;

  #say STDERR $d->printInOrder; exit;
  is_deeply($d->print, <<END);
Length: 13
   x,   y      X,   Y   L  Name     Path
   8,   0      8,   8   1  c        32,0 6,0 6,8 8,8
END

  is_deeply($d->printPath($c), <<END);
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
 }

#latest:;
if (1)                                                                          #
 {my      $d = new;
  my $e = $d->wire(m4(0, 2, 1, 1), n=>'e');
          $d->layout;

  #say STDERR $d->printInOrder; exit;
  is_deeply($d->print, <<END);
Length: 9
   x,   y      X,   Y   L  Name     Path
   0,   8      4,   4   1  e        0,32 0,8 2,4 4,4
END

  is_deeply($d->printPath($e), <<END);
.....
.....
.....
.....
..00F
..1..
..1..
..1..
S01..
END
 }

#latest:;
if (1)                                                                          #
 {my      $d = new;
  my $f = $d->wire(m4(0, 3, 4, 0), n=>'f');
          $d->layout;

  #say STDERR $d->printInOrder; exit;
  is_deeply($d->print, <<END);
Length: 29
   x,   y      X,   Y   L  Name     Path
   0,  12     16,   0   1  f        0,48 0,10 14,10 14,0 16,0
END

  is_deeply($d->printPath($f), <<END);
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
 }

#latest:;
if (1)                                                                          #
 {my      $d = new;
  my $F = $d->wire(m4(1, 3, 3, 0), n=>'F');
          $d->layout;
  #say STDERR $d->printInOrder; exit;
  is_deeply($d->print, <<END);
Length: 21
   x,   y      X,   Y   L  Name     Path
   4,  12     12,   0   1  F        16,48 4,10 10,10 10,0 12,0
END

  is_deeply($d->printPath($F), <<END);
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
....0000001..
....1........
....S........
END
 }

#latest:;
if (1)                                                                          #Tlayout
 {my      $d = new;
  my $g = $d->wire(m4(0, 0, 3, 0), n=>'g');
          $d->layout;

  #say STDERR $d->printInOrder; exit;
  is_deeply($d->print, <<END);
Length: 17
   x,   y      X,   Y   L  Name     Path
   0,   0     12,   0   1  g        0,0 0,2 12,2 12,0
END

  is_deeply($d->printPath($g), <<END);
S...........F
1...........1
0000000000001
END
 }

#latest:;
if (1)                                                                          #Tnew #Twire #TtotalLength
 {my        $d = new;
  my $a =   $d->wire(m4(0, 1, 2, 1), n=>'a');
  my $b =   $d->wire(m4(1, 0, 1, 2), n=>'b');
  my $c =   $d->wire(m4(2, 0, 2, 2), n=>'c');
  my $e =   $d->wire(m4(0, 2, 1, 1), n=>'e');
  my $f =   $d->wire(m4(0, 3, 4, 0), n=>'f');
  my $F =   $d->wire(m4(1, 3, 3, 0), n=>'F');

            $d->layout;
  is_deeply($d->levels, 1);

  my $g =   $d->wire(m4(0, 0, 3, 0), n=>'g');

            $d->layout;
  is_deeply($d->levels, 2);
  is_deeply($d->totalLength, 119);

  #say STDERR $d->printInOrder; exit;
  is_deeply($d->printInOrder, <<END);
Length: 119
   x,   y      X,   Y   L  Name     Path
   0,   0     12,   0   2  g        0,0 0,2 12,2 12,0
   0,   4      8,   4   1  a        0,16 0,2 8,2 8,4
   0,   8      4,   4   1  e        0,32 0,6 4,6 4,4
   0,  12     16,   0   1  f        0,48 0,10 14,10 14,0 16,0
   4,   0      4,   8   1  b        16,0 2,0 2,8 4,8
   4,  12     12,   0   1  F        16,48 4,12 4,14 10,0 12,0
   8,   0      8,   8   1  c        32,0 6,0 6,8 8,8
END

  is_deeply($d->printPath($a), <<END);
.........
.........
000000001
1.......1
S.......F
END

  is_deeply($d->printPath($b), <<END);
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

  is_deeply($d->printPath($c), <<END);
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

  is_deeply($d->printPath($e), <<END);
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

  is_deeply($d->printPath($f), <<END);
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

  is_deeply($d->printPath($F), <<END);
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


  is_deeply($d->printPath($g), <<END);
S...........F
1...........1
0000000000001
END
  $d->svg (svg=>q(xy2), pngs=>2);
  $d->gds2(svg=>q/xy2/);
 }

#latest:;
if (1)                                                                          #Tnew #Twire #TtotalLength
 {my $d = new;
     $d->wire(0,  0, 12,  0);
     $d->wire(0, 16, 12, 16);
     $d->wire(0, 12, 12,  8);
     $d->wire(0,  4,  8,  8);
     $d->wire(8,  0, 16,  0);
     $d->wire(4,  0, 16,  4);
     $d->wire(8, 16, 12, 12);
     $d->wire(4,  4,  4,  8);
     $d->wire(4, 12,  4, 16);
     $d->layout;
  $d->svg (svg=>q(test3), pngs=>2);
  $d->gds2(svg=>q(test3));
  is_deeply($d->print, <<END);
Length: 153
   x,   y      X,   Y   L  Name     Path
   0,   0     12,   0   1           0,0 0,2 12,2 12,0
   0,  16     12,  16   1           0,64 0,14 12,14 12,16
   0,  12     12,   8   1           0,48 0,10 12,10 12,8
   0,   4      8,   8   1           0,16 0,4 0,6 8,6
   8,   0     16,   0   1           32,0 8,0 10,0 10,6 14,0 16,0
   4,   0     16,   4   1           16,0 4,0 6,0 6,18 18,4 16,4
   8,  16     12,  12   1           32,64 8,16 10,12 12,12
   4,   4      4,   8   1           16,16 4,4
   4,  12      4,  16   1           16,48 4,12
END
 }

&done_testing;
finish: 1
