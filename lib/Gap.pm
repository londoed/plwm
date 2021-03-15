###
 # plwm: A tiling window manager, written in Perl, for the X Windowing System.
 #
 # Copyright (C) 2021, Eric Londo <londoed@comcast.net>, { lib/Gap.pm }.
 # This software is distributed under the GNU General Public License Version 2.0.
 # Refer to the file LICENSE for additional details.
###

package Gap;
use CommandObject;
our @ISA = qw(CommandObject);

my $STRETCH = new Obj("STRETCH");
my $CALCULATED = new Obj("CALCULATED");
my $STATIC = new Obj("STATIC");

###
 # A gap placed along one of the edges of the screen.
 #
 # If a gap has been defined, plwm will avoid covering it up with windows.
 # The most probable reason for configuring a gap is to make space for a
 # third-party bar or other static window.
###

sub new {
	my $type = Plwm::Gap;
	my $self = {
		$size => shift,
		$initial_size => shift,
		$length => shift,
		$tile => shift,
		$screen => shift,
		$x => shift,
		$y => shift,
		$width => shift,
		$height => shift,
		$horizontal => shift,
	};
}

sub configure {
	$self->{qtile} = shift;
	$self->{screen} = shift;

	if ($screen->{top} ~~ $type) {
		$self->{x} = $screen->{x};
		$self->{y} = $screen->{y};
		$self->{length} = $screen->{width};
		$self->{width} = $screen->{length};
		$self->{height} = $screen->{initial_size};
		$self->{horizontal} = True;
	} elsif ($screen->{bottom} ~~ $type) {
		$self->{x} = $screen->{x};
		$self->{y} = $screen->{y};
		$self->{length} = $screen->{width};
		$self->{height} = $screen->{initial_size};
		$self->{horizontal} = True; 
	} elsif ($screen->{left} ~~ $type) {
		$self->{x} = $screen->{x};
		$self->{y} = $screen->{dy};
		$self->{length} = $screen->{dheight};
		$self->{width} = $screen->{initial_size};
		$self->{height} = $screen->{length};
		$self->{horizontal} = False;
	} else {
		$self->{x} = $screen->{dx} + $screen->{dwidth};
		$self->{y} = $screen->{dy};
		$self->{length} = $screen->{height};
		$self->{width} = $screen->{initial_size};
		$self->{height} = $screen->{length};
		$self->{horizontal} = False;
	}
}

sub draw {
	die "[!] ERROR: plwm: Undefined method for Gap: draw()";
}

sub finalize {
	die "[!] ERROR: plwm: Undefined method for Gap: finalize()";
}

sub geometry {
	return ($self->{x}, $self->{y}, $self->{width}, $self->{height});
}

sub items {
	my $name = shift;

	if ($name eq "screen") {
		return (True, undef);
	}
}

sub select {
	my ($name, $sel) = @_;

	if ($name eq "screen") {
		return $self->{screen};
	}
}

sub position {
	foreach my $i (qw(top bottom left right)) {
		if ($self->{screen} eq i) {
			return $i;
		}
	}
}

sub info {
	return { $position => $self->{position} };
}

sub cmd_info {
	return $self->{info};
}


