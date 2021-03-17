###
 # plwm: A highly-configurable tiling window manager, written in Perl, for the X Windowing System.
 #
 # Copyright (C) 2021, Eric Londo <londoed@comcast.net>, { lib/Popup.pm }.
 # This software is distributed under the GNU General Public License Version 2.0.
 # Refer to the file LICENSE for additional details.
###

use XCB::XProto;
use Plwm;

package Popup;
our @ISA = qw(Configurable::Configurable);

my @defaults = (
	('opacity', 1.0, 'Opacity of notifications'),
	('foreground', '#ffffff', 'Color of text'),
	('background', '#111111', 'Background color'),
	('border', '#111111', 'Border color'),
	('border_width', 0, 'Line width of drawn borders'),
	('corner_radius', undef, 'Corner radius for round corners, or Undefined'),
	('font', 'Ubuntu Mono', 'Font used in notifications'),
	('font_size', '12', 'Size of font used'),
	('fontshadow', undef, 'Color for text shadows, or Undefined for no shadows'),
	('horizontal_padding', 0, 'Padding at sides of text'),
	('vertical_padding', 0, 'Padding at top and bottom of text'),
	('text_alignment', 'left', 'Text alignment: left, center or right'),
	('wrap', True, "Whether to wrap text"),
);

sub new {
	my $class = @_;
	my $self = $class->SUPER::new($_[1], $_[2], $_[3], $_[4], $_[5], $_[6]);
	
	$self->add_defaults($self->{defaults});
	$self->{plwm} = $plwm;

	my $win = $_[1]->{conn}->create_window($x, $y, $width, $height);
	$win->set_property('PLWM_INTERVAL', 1);
	$self->{win} = Window::Internal->new($win, $plwm);
	$self->{plwm}->{windows_map}[$self->{win}->{window}->{wid}] = $self->{win};
	$self->{win}->{opacity} = $self->{opacity};
	$self->{drawer} = Drawer::Drawer->new(
		$self->{plwm}, $self->{win}->{window}->{wid}, $width, $height
	);

	$self->{layout} = $self->{drawer}->text_layout(
		text => '',
		color => $self->{foreground},
		font_family => $self->{font},
		font_size => $self->{font_size},
		font_shadow => $self->{font_shadow},
		wrap => $self->{wrap},
		markup => True
	);

	$self->{layout}->{layout}->set_alignment(XCB::Pango->{alignments}[$self->{text_alignments}]);

	if (defined $self->{border_width}) {
		$self->{win}->{window}->configure(border_width => $self->{border_width});
	}

	if (defined $self->{corner_radius}) {
		$self->{win}->{window}->round_corners($width, $height, $self->{corder_radius}, $self->{border_width});
	}

	$self->{win}->handle_expose = $self->handle_expose;
	$self->{win}->handle_key_press = $self->handle_key_press;
	$self->{win}->handle_button_press = $self->handle_button_press;

	$self->{x} = $self->{win}->{x};
	$self->{y} = $self->{win}->{y};

	if (!defined $self->{border_width}) {
		$self->border = undef;
	}

	bless $self, $class;
	return $self;
}

sub handle_expose {
	my $e = shift;

	...;
}

sub handle_key_press {
	my $event = shift;

	...;
}

sub handle_button_press {
	if ($event->{detail} == 1) {
		$self->hide();
	}
}

sub width {
	return $self->{win}->{width};
}

sub set_width {
	my $value = shift;
	$self->{win}->{width} = $value;
	$self->{drawer}->{width} = $value;
}

sub height {
	return $self->{win}->{height};
}

sub set_height {
	my $value = shift;
	$self->{win}->{height} = $value;
	$self->{drawer}->{height} = $value;
}

sub text {
	return $self->{layout}->{text};
}

sub set_text {
	my $value = shift;
	$self->{layout}->{text} = $value;
}

sub foreground {
	return $self->{foreground};
}

sub foreground_set {
	my $value = shift;
	$self->{foreground} = $value;

	if ($self->has_attr('layout')) {
		$self->{layout}->{color} = $value;
	}
}

sub set_border {
	my $color = shift;
	$self->{win}->{window}->paint_borders($color);
}

sub clear {
	$self->{drawer}->clear($self->{background});
}

sub draw_text {
	my ($x, $y) = @_;
	$self->{layout}->draw(
		$x || $self->{horizontal_padding},
		$y || $self->{vertical_padding},
	);
}

sub draw {
	$self->{drawer}->draw();
}

sub place {
	$self->{win}->place(
		$self->{x},
		$self->{y},
		$self->{width},
		$self->{height},
		$self->{border_width},
		$self->{border},
		above => True
	);
}

sub unhide {
	$self->{win}->unhide();
	$self->{win}->{window}->configure(stack_mode => XCB::StackMode::Above);
}

sub draw_image {
	my ($image, $x, $y)
	$self->{drawer}->{ctx}->set_source_surface($image, $x, $y);
	$self->{drawer}->{ctx}->paint();
}

sub hide {
	$self->{win}->hide();
}

sub kill {
	$self->{win}->kill();
}



