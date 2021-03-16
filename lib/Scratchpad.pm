###
 # plwm: A highly-configurable tiling window manager, written in Perl, for the X Windowing System.
 #
 # Copyright (C) 2021, Eric Londo <londoed@comcast.net>, { lib/Scratchpad.pn }.
 # This software is distributed under the GNU General Public License Version 2.0.
 # Refer to the file LICENSE for additional details.
###

use Plwm;

package WindowVisibilityToggler;

sub new {
	my %self = {
		$scratchpad_name => shift,
		$window => shift,
		$on_focus_lost_hide => shift,
		$warp_pointer => shift,
	};

	my $shown = False;
	$self->show();
}

sub info {
	return {
		window => $self->{window}->info(),
		visible => $self->{visible},
		on_focus_lost_hide => $self->{on_focus_lost_hide},
		warp_pointer => $self->{warp_pointer},
	};
}

sub visible {
	if (!defined $self->{window}->{group}) {
		return False;
	}

	return ($self->{window}->{group}->{name} != $self->{scratchpad_name} &&
		$self->{window}->{group} == $self->{window}->{plwm}->{current_group});
}

sub toggle {
	if (!defined $self->{visible} || !defined $self->{shown}) {
		$self->show();
	} else {
		$self->hide();
	}
}

sub show {
	if (!defined $self->{visible} || !defined $self->shown) {
		my $win = $self->{window};
		$win->{float_state} = $window->{TOP};
		$win->to_group();
		$win->cmd_bring_to_front();
		$self->{showm} = True;
	}

	if ($self->{on_focus_lost_hide}) {
		$win->{window}->warp_pointer($win->{width} // 2, $win->{height} // 2) if $self->{warp_pointer};
		$hook->{subscribe}->client_focus($self->on_focus_change);
		$hook->{subscribe}->set_group($self->{on_focus_change});
	}
}

sub hide {
	if ($self->{visible} || $self->{shown}) {
		if ($self->{on_focus_lost_hide}) {
			$hook->{unsubscribe}->client_focus($self->{on_focus_change});
			$hook->{unsubscribe}->set_group($self->{on_focus_change});
		}

		$self->{window}->to_group($self->{scratchpad_name});
		$self->{shown} = False;
	}
}

sub unsubscribe {
	if ($self->{focus_on_lost_hide} && ($self->{visible} || $self->{shown})) {
		$hook->{unsubscribe}->client_focus($self->{on_focus_change});
		$hook->{unsubscribe}->set_group($self->{on_focus_change});
	}
}

sub on_focus_change {
	if ($self->{shown}) {
		my $current_group = $self->{window}->{plwm}->{current_group};

		if ($self->{window}->{group} != $current_group || $self->{window} != $current_group->{current_window}) {
			$self->hide() if (defined $self->{on_focus_lost_hide});
		}
	}
}

package DropDownToggler;
our @ISA = qw(WindowVisibilityToggler);

sub new {
	my $class = @_;
	my $self = $class->SUPER::new($_[1], $_[2], $_[3]);

	my $name = $ddconfig->{name};
	my $x = $ddconfig->{x};
	my $y = $ddconfig->{y};
	my $width = $ddconfig->{width};
	my $height = $ddconfig->{height};

	$window->set_opacity($ddconfig->{opacity});

	bless $self, $class;
	return $self;
}

sub info {
	my %info = WindowVisibilityManager::info($self);
	%info->update({
		x => $self->{x},
		y => $self->{y},
		width => $self->{width},
		height => $self->{height},
	});

	return %info;
}

sub show {
	if (!defined $self->{visible} || !defined $self->{shown}) {
		my $win = $self->{window};
		my $screen = $win->{plwm}->{current_screen};

		$win->{x} = round $screen->{dx} + $self->{x} * $screen->{dwidth};
		$win->{y} = round $screen->{dy} + $self->{y} * $screen->{dheight};
		$win->{float_x} = $win->{x};
		$win->{float_y} = $win->{y};
		$win->{width} = round $screen->{dwidth} * $self->{width};
		$win->{height} = round $screen->{dheight} * $self->{height};

		$win->reconfigure_floating();

		WindowVisibilityToggler->show($self);
	}
}

package ScratchPad;
our @ISA = qw(Group::_Group);

sub new {

}
