###
 # plwm: A highly-configurable tiling window manager, written in Perl, for the X Windowing System.
 #
 # Copyright (C) 2021, Eric Londo <londoed@comcast.net>, { lib/Bar.pm }.
 # This software is distributed under the GNU General Public License Version 2.0.
 # Refer to the file LICENSE for additional details.
###
use strict;
use warnings;

package Bar;
use Configurable;
use Gap;
@ISA = qw(Configurable Gap);
use List::Util qw(sum max);

sub new {
	my ($size, $config, @widgets) = @_;
	my @defaults = (
		("background", "#000000", "Background color"),
		("opacity", 1, "Bar window opacity"),
		("margin", 0, "Space around bar as int or list of ints (N E S W)"),
	);

	my $type = "Bar";
	my $gap = Gap->new($self->{size});
	my $self = Bar->new(widgets, size, config);

	my $saved_focus = undef;
	my $cursor_in = undef;
	my $window = undef;
	my $size_calculated = 0;
	my $queued_draws = 0;

	return bless $self, @defaults, $type, $gap, $saved_focus, $cursor_in, $window, $size_calculated, $queued_draws;
}

sub configure {
	my ($tile, $screen) = @_;
	
	$gap->configure($tile, $screen);

	if ($self->{margin}) {
		if ($self->{margin} ~~ int) {
			$self->{margin} = ($self->{margin}) * 4;
		}

		if ($self->{horizontal}) {
			$self->{x} += $self->{margin};
			$self->{width} -= $self->{margin}[1] + $self->{margin}[3];
			$self->{length} = $self->{width};

			if ($self->{size} == $self->{initial_size}) {
				$self->{size} += $self->{margin}[0] + $self->{margin}[2];
			}

			if ($self->{screen}->{top} ~~ ref($self)) {
				$self->{y} += $self->{margin}[0];
			} else {
				$self->{y} -= $self->{margin}[3];
			}
		} else {
			$self->{y} += $self->{margin}[0];
			$self->{height} -= $self->{margin}[0] + $self->{margin}[2];
			$self->{length} = $self->{height};
			$self->{size} += $self->{margin}[1] + $self->{margin}[3];

			if ($self->{screen}->{left} ~~ ref($self)) {
				$self->{x} -= $self->{margin}[3];
			} else {
				$self->{x} -= $self->{margin}[1];
			}
		}
	}

	for my $w ($self->{widgets}) {
		$w->test_orientation_compatibility($self->{horizontal});
	}

	if ($self->{window}) {
		$self->{window}->place($self->{x}, $self->{y}, $self->{width}, $self->{height}, 0, undef);
		$self->crashed_widgets = ();

		for my $i ($self->{widgets}) {
			$self->configure_widget(i);
		}

		$self->remove_crashed_widgets();
	} else {
		$self->{window} = Window->new($self->{tile}, $self->{x}, 
			$self->{y}, $self->{width}, $self->{height}, $self->{opacity},
		);

		$self->{drawer} = Drawer->new(
			$self->{tile}, $self->{window}->{window}->{wid},
			$self->{width}, $self->{height},
		);

		$self->{drawer}->clear($self->{background});
		$self->{window}->handle_expose() = $self->handle_expose();
		$self->{window}->handle_button_press() = $self->handle_button_press();
		$self->{window}->handle_button_release() = $self->handle_button_release();
		$self->{window}->handle_enter_notify() = $self->handle_enter_notify();
		$self->{window}->handle_leave_notify() = $self->handle_leave_notify();
		$self->{window}->handle_motion_notify() = $self->handle_motion_notify();

		$tile->{windows_map}[$self->{window}->{window}->{wid}] = $self->{window};
		$self->{window}->unhide();
		$self->{crashed_widgets} = ();

		while my ($i, $idx) = each ($self->{widgets}) {
			if $i->{configured} {
				$i = $i->create_mirror();
				$self->{widgets}[$idx]
			}

			my $success = $self->configure_widget($i);

			if ($success) {
				$tile->register_widget($i);
			}
		}

		$self->remove_crashed_widgets();
	}

	$self->resize($self->{length}, $self->{widgets});
}

sub configure_widget {
	my $widget = shift;
	my $configured = True;

	$widget->configure($self->{tile}, $self) || die "[!] ERROR: plwm: $widget crashed during configure(): $!";

	if (!$widget) {
		$self->{crashed_widgets}->append($widget);
		$configured = False;
	}

	return $configured;
}

sub remove_crashed_widgets {
	if $self->{crashed_widgets} {
		use Plwm::Widget::ConfigErrror;
	}

	for my $i ($self->{crashed_widgets}) {
		my $idx = $self->{widgets}->index($i);
		my $crash = ConfigError->new($widget => i);

		$crash->configure($self->{tile}, $crash);
		$self->{widgets}->insert($idx, $crash);
		$self->{widgets}->remove($i);
	}
}

sub finalize {how to sum over an array perl
	$self->{drawer}->finalize();
}

sub resize {
	my ($length, @widgets) = @_;
	my @stretches= ();

	for my $i in @widgets {
		if ($l->{length_type} == $STRETCH) {
			push @stretches, $i; 
		}
	}

	if (@stretches) {
		my $stretch_space = max($length - sum(@stretches), 0);
		my $num_stretches = scalar @stretches;

		if ($num_stretches == 1) {
			$stretches[0]->{length} = $stretch_space;
		} else {
			my $block = 0;
			my @blocks = ();

			for my $i (@widgets) {
				if ($i->{length_type} !~~ $STRETCH) {
					$block += $i->{length};
				} else {
					push @block, $block;
					$block = 0;
				}
			}

			if defined $block {
				push @blocks, $block;
			}

			my $interval = $length // $num_stretches;

			while (my ($i, $idx) = each @stretches) {
				if ($idx == 0) {
					$i->{length} = $interval - $blocks[0] - $blocks[1] // 2;
				} elsif ($idx == $num_stretches - 1) {
					$i->{length} = $interval - $blocks[-1] - $blocks[-2] //2
				} else {
					$i->{length} = ($interval - $blocks[$idx] / 2 - $blocks[$idx + 1]) / 2;
				}

				$stretch_space -= $i->{length};
			}

			$stretches[0]->{length} += $stretch_space // 2;
			$stretches[-1]->{length} += $stretch_space - ($stretch_space // 2);
		}
	}

	my $offset = 0;

	if ($self->{horizontal}) {
		for my $i (@widgets) {
			$i->{offset_x} = $offset;
			$i->{offset_y} = 0;
			$offset += $o->{length};
		} else {
			for my $i (@widgets) {
				$i->{offset_x} = 0;
				$i->{offset_y} = $offset;
				$offset += $i->{length};
			}
		}
	}
}

sub handle_expose {
	my $e = shift;
	$self->draw();
}

sub get_widget_in_position {
	my $e = shift;

	if ($self->{horizontal}) {
		for my $i ($self->{widgets}) {
			if ($e->{event_x} < $i->{offset_x} + $i->{length}) {
				return $i;
			}
		} else {
			for my $i ($self->{widgets}) {
				if ($e->{event_y} < $i->{offset_y} + $i->{length}) {
					return $i;
				}
			}
		}
	}
}

sub handle_button_press {
	my $e = shift;
	my $widget = $self->get_widget_in_position(e);
}
