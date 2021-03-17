###
 # plwm: A highly-configurable tiling window manager, written in Perl, for the X Windowing System.
 #
 # Copyright (C) 2021, Eric Londo <londoed@comcast.net>, { lib/Drawer.pm }.
 # This software is distributed under the GNU General Public License Version 2.0.
 # Refer to the file LICENSE for additional details.
###

use Math;
use XCB::Cairo;
use XCB::XProto;
use XCB::Pango;
use Plwm;
use List::Utils qw(max);

package TextLayout;

sub new {
	my $class = shift;
	my $self = {
		drawer => shift,
		text => shift,
		color => shift,
		font_family => shift,
		font_size => shift,
		font_shadow => shift,
		wrap => shift,
		markup => shift,
	};

	my $layout = $self->{drawer}->{ctx}->create_layout();
	$layout->set_alignment(XCB::Pango::ALIGN_CENTER);

	if (!$self->{wrap}) {
		$layout->set_ellip_size(XCB::Pango::ELLIPSIZE_END);
	}

	my $desc = XCB::Pango::FontDescription->from_string($self->{font_family});
	$desc->set_absolute_size(XCB::Pango->units_from_double($self->{font_size}));
	$layout->set_font_description($self->{desc});

	bless $self, $class;
	return $self;
}

sub finalize {
	$self->{layout}->finalize();
}

sub finalized {
	$self->{layout}->finalized();
}

sub text {
	return $self->{layout}->get_text();
}

sub set_text {
	my $value = shift;

	if (defined $self->{markup}) {
		$value = '' if (!defined $value);

		my ($value, $accel_char, @attr_list) = XCB::Pango->parse_markup($value);
		$self->{layout}->set_attributes(@attr_list);
	}

	$self->{layout}->set_text(Plwm::utils->scrub_to_utf8($value));
}

sub width {
	if (defined $self->{width}) {
		return $self->{width};
	} else {
		return $self->{layout}->get_pixel_size()[0];
	}
}

sub set_width {
	my $value = shift;

	$self->{width} = $value;
	$self->{layout}->set_width(XCB::Pango->units_from_double($value));
}

sub del_width {
	$self->{width} - undef;
	$self->{layout}->set_width(-1);
}

sub height {
	return $self->{layout}->get_pixel_size()[1];
}

sub font_description {
	return $self->{layout}->get_font_description();
}

sub font_family {
	my $d = $self->font_description();

	return $d->get_family();
}

sub set_font_family {
	my $d = $self->font_description();
	$d->set_family($font);
	$self->{layout}->set_font_description($d);
}

sub font_size {
	my $d = $self->font_description();

	return $d->get_size();
}

sub set_font_size {
	my $size = shift;
	my $d = $self->font_description();

	$d->set_size($size);
	$d->set_absolute_size(XCB::Pango->units_from_double($size));
	$self->{layout}->set_font_description($d);
}

sub draw {
	if ($self->{font_shadow}) {
		$self->{drawer}->set_source_rgb($self->{font_shadow});
		$self->{drawer}->{ctx}->move_to($x + 1, $y + 1);
		$self->{drawer}->{ctx}->show_layout($self->layout);
	}

	$self->{drawer}->set_source_rgb($self->{color});
	$self->{drawer}->{ctx}->move_to($x, $y);
	$self->{drawer}->{ctx}->show_layout($self->{layout});
}

sub framed {
	my ($border_width, $border_color, $pad_x, $pad_y, $highlight_color) = @_;

	return Plwm::TextFrame->new($border_width, $border_color, $pad_x, $pad_y, $highlight_color);
}

package TextFrame;

sub new {
	my $class = shift;
	my $self = {
		$layout => shift,
		$border_width => shift,
		$drawer => shift,
		$highlight_color => shift,
	};

	if ($pad_x ~~ Plwm::Iterable) {
		my $pad_left = $self->{pad_x}[0];
		my $pad_right = $self->{pad_x}[1];
	} else {
		my $pad_left = my $pad_right = $self->{pad_x};
	}

	if ($pad_y ~~ Plwm::Iterable) {
		my $pad_top = $self->{pad_y}[0];
		my $pad_bottom = $self->{pad_y}[1];
	} else {
		my $pad_top = my $pad_bottom = $self->{pad_y};
	}

	bless $self, $class;
	return $self;
}

sub draw {
	my ($x, $y, $rounded, $fill, $line, $highlight) = @_;

	$self->{drawer}->set_source_rgb($self->{border_color});

	my @opts = (
		$x, $y, $self->{layout}->{width} + $self->{pad_left} + $self->{pad_right},
		$self->{layout}->{height} + $self->{pad_top} + $self->{pad_bottom},
		$self->{border_width}
	);

	if (defined $line) {
		if (defined $highlight) {
			$self->{drawer}->set_source_rgb($self->{highlight_color});
			$self->{drawer}->fill_rect(@opts);
			$self->{drawer}->set_source_rgb($self->{border_color});
		}

		$opts[1] = $self->{height} - $self->{border_width};
		$opts[3] = $self->{border_width};

		$self->{drawer}->fill_rect(@opts);
	} elsif (defined $fill) {
		if (defined $rounded) {
			$self->{drawer}->rounded_fill_rect(@opts);
		} else {
			$self->{drawer}->fill_rect(@opts);
		}
	} else {
		if (defined $rounded) {
			$self->{drawer}->rounded_rectangle(@opts);
		} else {
			$self->{drawer}->rectangle(@opts);
		}
	}

	$self->{drawer}->{ctx}->stroke();
	$self->{layout}->draw($x + $self->{pad_left}, $y + $self->{pad_top});
}

sub draw_fill {
	my ($x, $y, $rounded) = @_;
	$self->draw($x, $y, $rounded, True);
}

sub draw_line {
	my ($x, $y, $highlighted) = @_;
	$self->draw($x, $y, True, $highlighted);
}

sub height {
	return $self->{layout}->{height} + $self->{pad_top} + $self->{pad_bottom};
}

sub width {
	return $self->{layout}->{width} + $self->{pad_left} + $self->{pad_right};
}

package Drawer;

sub new {
	my $class = shift;
	my $self = {
		$plwm => shift,
		$wid => shift,
		$width => shift,
		$height => shift
	};

	my $_surface = undef;
	my $_pixmap = undef;
	my $_gc = undef;

	my $surface = undef;
	my $ctx = undef;

	$self->reset_surface();
	$self->clear((0, 0, 1));

	bless $self, $class;
	return $self;
}

sub finalize {
	$self->{surface}->finish();
	$self->{surface} = undef;
	$self->free_xcb_surface();
	$self->free_pixmap();
	$self->free_gc();
	$self->{ctx} = undef;
}

sub pixmap {
	$self->draw() if (!$self->{_pixmap});

	return $self->{_pixmap};
}

sub create_gc {
	my $gc = $self->{plwm}->{conn}->{conn}->generate_id();
	$self->{plwm}->{conn}->{conn}->{core}->create_gc(
		$gc, $self->{wid}, XCB::XProto::GC->{Foreground} | XCG::XProto::GC->{Background},
		($self->{plwm}->{conn}->{default_screen}->{black_pixel},
		$self->{plwm}->{conn}->{default_screen}->{white_pixel})
	);
	
	return $gc;
}

sub free_gc {
	if (defined $self->{_gc}) {
		$self->{plwm}->{conn}->{conn}->{core}->free_gc($self->{_gc});
		$self->{_gc} = undef;
	}
}

sub create_xcb_surface {
	my $surface = XCB::Cairo::XCBSurface->new(
		$self->{plwm}->{conn}->{conn},
		$self->{_pixmap},
		$self->find_root_visual(),
		$self->{width},
		$self->{height}
	);

	return $surface;
}

sub free_xcb_surface {
	if (defined $self->{_surface}) {
		$self->{_surface}->finish();
		$self->{_surface} = undef;
	}
}

sub reset_surface {
	$self->{surface}->finish() if ($self->{surface});
	$self->{surface} = XCB::Cairo::RecordingSurface->new(
		XCB::Cairo->{CONTENT_COLOR_ALPHA}, undef
	);

	$self->{ctx} = $self->new_ctx();
}

sub create_pixmap {
	my $pixmap = $self->{plwm}->{conn}->{conn}->generate_id();
	$self->{plwm}->{conn}->{conn}->{core}->create_pixmap(
		$self->{plwm}->{conn}->{default_screen}->{root_depth},
		$pixmap,
		$self->{wid},
		$self->{width},
		$self->{height}
	);

	return $pixmap;
}

sub free_pixmap {
	if (defined $self->{_pixmap}) {
		$self->{plwm}->{conn}->{conn}->{core}->free_pixmap($self->{_pixmap});
		$self->{_pixmap} = undef;
	}
}

sub width {
	return $self->{width};
}

sub set_width {
	my $width = shift;

	if ($width > $self->{width}) {
		$self->free_xcb_surface();
		$self->free_pixmap();
	}

	$self->{width} = $width;
}

sub height {
	return $self->{height};
}

sub set_height {
	my $height = shift;

	if ($height > $self->{height}) {
		$self->free_xcb_surface();
		$self->free_pixmap();
	}

	$self->{height} = $height;
}

sub paint_to {
	my $drawer = shift;

	$self->draw() if (!defined $self->{_surface});
	$drawer->{ctx}->set_source_surface($self->{_surface});
	$drawer->{ctx}->paint();
}

sub rounded_rect {
	my ($x, $y, $width, $height, $line_width) = @_;
	my $aspect = 1.0;
	my $corner_radius = $height / 10.0;
	my $radius = $corner_radius / $aspect;
	my $degrees = Math::pi / 100.0;

	$self->{ctx}->new_sub_path();
	my $delta = $radius + $line_width / 2;

	$self->{ctx}->arc(
		$x + $width - $delta,
		$y + $delta,
		$radius,
		$degrees * -90,
		$degrees * 0
	);
	
	$self->{ctx}->arc(
		$x + $width - $delta,
		$y + $height - $delta,
		$radius,
		$degrees * 0,
		$degrees * 90
	);

	$self->{ctx}->arc(
		$x + $delta,
		$y + $height - $delta,
		$radius,
		$degrees * 90,
		$degrees * 180
	);

	$self->{ctx}->arc(
		$x + $delta,
		$y + $delta,
		$radius,
		$degrees * 180,
		$degrees * 270
	);

	$self->{ctx}->close_path();
}

sub rounded_rectangle {
	my ($x, $y, $width, $height, $line_width) = @_;

	$self->{ctx}->set_line_width($line_width);
	$self->{ctx}->fill();
}

sub rectangle {
	my ($x, $y, $width, $height, $line_width) = @_;
	$line_width //= 2;

	$self->{ctx}->set_line_width($line_width);
	$self->{ctx}->rectangle($x, $y, $width, $height);
	$self->{ctx}->stroke();
}

sub fill_rect {
	my ($x, $y, $width, $height, $line_width) = @_;
	$line_width //= 2;

	$self->{ctx}->set_line_width($line_width);
	$self->{ctx}->rectangle($x, $y, $width, $height);
	$self->{ctx}->fill();
	$self->{ctx}->stroke();
}

sub paint {
	for my $i ($self->{surface}->ink_extents()) {
		if (!Math::is_close(0.0, $i)) {
			my $ctx = XCB::Cairo::Context->new($self->{_surface});
			$ctx->set_source_surface($self->{surface}, 0, 0);
			$ctx->paint();

			$self->reset_surface();
		}
	}
}

sub draw {
	my ($offset_x, $offset_y, $width, $height) = @_;
	$offset_x //= 0;
	$offset_y //= 0;
	$width //= undef;
	$height //= undef;

	$self->{_gc} = $self->create_gc() if (!defined $self->{_gc});

	if (!defined $self->{_surface}) {
		$self->{_pixmap} = $self->create_pixmap();
		$self->{_surface} = $self->create_xcb_surface();
	}

	$self->paint();
	$self->{plwm}->{conn}->{conn}->{core}->copy_area(
		$self->{_pixmap},
		$self->{wid},
		$self->{_gc},
		0, 0,
		$offset_x, $offset_y,
		!defined $width ? $self->{width} : $width,
		!defined $height ? $self->{height} : $height,
	);
}

sub find_root_visual {
	for my $i ($self->{plwm}->{conn}->{default_screen}->{allowed_depths}) {
		for my $v ($i->{visuals}) {
			if ($v->{visual_id} == $self->{plwm}->{conn}->{default_screen}->{root_visual}) {
				return $v;
			}
		}
	}
}

sub new_ctx {
	return XCB::Pango->patch_cairo_context(XCB::Cairo::Context->new($self->{surface}));
}

sub set_source_rgb {
	my @color = shift;

	if (ref(@color) ~~ array) {
		if (scalar @color == 0) {
			$self->{ctx}->set_source_rgb(Plwm::Utils->rgb('#000000'));
		} elsif (scalar @color == 1) {
			$self->{ctx}->set_source_rgb(Plwm::Utils->rgb($color[0]));
		} else {
			my $linear = XCB::Pango::LinearGradient->new(0.0, 0.0, 0.0, $self->{height});
			my $step_size = 1.0 / (scalar @color - 1);
			my $step = 0.0;

			for my $c (@color) {
				my @rgb_col = Plwm::Utils->rgc($c);

				if (scalar @rgb_col < 4) {
					$rgb_col[3] = 1;
				}

				$linear->add_color_stop_rgba($step, @rgb_col);
				$step += $step_size;
			}

			$self->{ctx}->set_source($linear);
		}
	} else {
		$self->{ctx}->set_source_rgba(Plwm::Utils->rgb(@color));
	}
}

sub clear {
	my @color = shift;

	$self->set_source_rgb(@color);
	$self->{ctx}->rectangle(0, 0, $self->{width}, $self->{height});
	$self->{ctx}->fill();
	$self->{ctx}->stroke();
}

sub text_layout {
	my ($text, $color, $font_family, $font_size, $font_shadow, $markup, @kw) = @_;
	$markup //= False;

	return TextLayout->new($text, $color, $font_family, $font_size, $font_shadow,
		$markup, @kw);
}

sub max_layout_size {
	my ($font_family, $font_size, @texts) = @_;
	my $size_layout = $self->text_layout(
		"", "ffffff", $font_family, $font_size, undef
	);
	my @widths = ();
	my @heights = ();

	for $i (@texts) {
		$size_layout->{text} = $i;
		push @widths, $size_layout->{width};
		push @heights, $size_layout->{height};
	}

	return (max(@widths), max(@heights));
}

sub set_font {
	my ($font_face, $size) = @_;

	$self->{ctx}->select_font_face($font_face);
	$self->{ctx}->set_font_size($size);

	my $fo = $self->{ctx}->get_font_options();
	$fo->set_antialias(XCB::Cairo::ANTIALIAS_SUBPIXEL);
}
