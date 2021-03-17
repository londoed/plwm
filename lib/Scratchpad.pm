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
	my $class = @_;
	my $self = $class->SUPER::new($_[1], $_[2], $_[3]);
	my %dropdown_config = {};

	for my $dd (@dropdowns) {
		$dropdown_conif{$dd->{name}} = $dd;
	}

	my %dropdowns = {};
	my %spawned = {};
	my @to_hide = ();

	bless $self, $class;
	return $self;
}

sub check_unsubscribe {
	if (!defined $self->{dropdowns}) {
		$hook->{unsubscribe}->client_killed($self->{on_client_killed});
		$hook->{unsubscribe}->float_change($self->{on_float_change});
	}
}

sub spawn {
	my $ddconfig = shift;
	my $name = $ddconfig->{name};

	if (!grep(/^$name/, $self->{spawned}->{values})) {
		if (!defined $self->{spawned}) {
			$hook->{subscribe}->client_new($self->{on_client_new});
		}

		my $cmd = $self->{dropdown_config}[$name]->{command};
		my $pid = $self->{plwm}->cmd_spawm($cmd);
		$self->{spawmed}[$pid] = $name;
	}
}

sub on_client_new {
	my $client_pid = $client->{window}->get_net_wm_pid();

	if (grep(/^$client_pid/, $self->{spawned})) {
		my $name = $self->{spawned}->pop($client_pid);

		if (!defined $self->{spawned}) {
			$hook->{unsubscribe}->client_new($self->{on_client_new});
		}

		$self->{dropdowns}[$name] = DropDownToggler->new($client, $self->{name}, $self->{dropdown_config}[$name]);

		if (grep(/^$name/, $self->{to_hide})) {
			$self->{dropdowns}[$name]->hide();
			$self->{to_hide}->remove($name);
		}

		if (scalar $self->{dropdowns} == 1) {
			$hook->subscribe->client_killed($self->{on_client_killed});
			$hook->subscribe->float_change($self->{on_float_change});
		}
	}
}

sub on_client_killed {
	my ($client, $args, $kwargs) = @_;
	my $name = undef;

	for (keys $self->{dropdowns}) {
		my $value = $self->{dropdowns}{$_};

		if ($value->{window} == $client) {
			$value->unsubscribe();
			delete $value;
			break;
		}
	}
	
	$self->check_unsubscribe();
}

sub on_float_change {
	my ($args, @kwargs) = @_;
	my $name = undef;

	for (keys $self->{dropdowns}) {
		my $value = $self->{dropdowns}{$_};
		
		if (!defined $value->{window}->{floating}) {
			$value->unsubscribe();
			delete $value;
			break;
		}
	}

	$self->check_unsubscribe();
}

sub cmd_dropdown_toggle {
	my $name = shift;

	if (grep(/^$name/, $self->{dropdowns})) {
		$self->{dropdowns}{$name}->toggle();
	} else {
		if (grep(/^$name/, $self->{dropdown_config})) {
			$self->spawn($self->dropdown_config[$name]);
		}
	}
}

sub cmd_dropdown_reconfigure {
	return if (!grep(/^$name/, $self->{dropdown_config}));

	my $dd = $self->{dropdown_config}{$name};

	for (keys %kwargs) {
		my $value = %kwarg{$_};

		if ($dd->has_attr($_)) {
			$dd->set_attr($_, $value);
		}
	}
}

sub cmd_dropdown_info {
	my $name = shift;

	if (!defined $name) {
		for my $ddname ($self->{dropdown_config}) {
			return $self->{dropdown_config}{'dropdowns'} = $ddname;
		}
	} elsif (grep(/^$name/, $self->{dropdowns})) {
		return $self->{dropdowns}{$name}->info();
	} elsif (grep(/^$name/, $self->{dropdown_config})) {
		return $self->dropdown_config[$name]->info();
	} else {
		die "[!] ERROR: plwm: No dropdown named : `$name`\n";
	}
}

sub get_state {
	my @state = ();

	for (keys $self->{dropdowns}) {
		my $value = $self->{dropdowns}{$_};
		my $pid = $value->{window}->{window}->get_net_wm_pid();
		push @state, ($name, $pid, $value->{visible});
	}

	return @state;
}

sub resore_state {
	my @state = shift;
	my @orphans = ();
	
	while my ($name, $pid, $visible) = each (@state) {
		if (grep(/^$name/, $self->{dropdown_configs})) {
			$self->{spawned}[$pid] = $name;

			if (!defined $visible) {
				push $self->{to_hide}, $name;
			} else {
				push @orphans, $pid;
			}
		}
	}

	if (defined $self->{spawned}) {
		$hook->{subscribe}->client_new($self->{on_client_new});
	}

	return @orphans;
}
