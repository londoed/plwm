###
 # plwm: A highly-configurable tiling window manager, written in Perl, for the X Windowing System.
 #
 # Copyright (C) 2021, Eric Londo <londoed@comcast.net>, { lib/Window.pm }.
 # This software is distributed under the GNU General Public License Version 2.0.
 # Refer to the file LICENSE for additional details.
###
 
use strict;
use warnings;

package Window;

use X11::Proto;
use Plwm qw(hook utils CommandError CommandObject logger);
use Math::Round;

# CONSTANTS #
our $NO_VALUE 															= 0x0000;
our $X_VALUE 																= 0x0001;
our $Y_VALUE 																= 0x0002;
our $WIDTH_VALUE 														= 0x0004;
our $HEIGHT_VALUE 													= 0x0008;
our $ALL_VALUES 														= 0x000f;
our $X_NEGATIVE 														= 0x0010;
our $Y_NEGATIVE 														= 0x0020;

our $INPUT_HINT 														= 1 << 0;
our $STATE_HINT 														= 1 << 1;
our $ICON_PIXMAP_HINT 											= 1 << 2;
our $ICON_WINDOW_HINT 											= 1 << 3;
our $ICON_POSITION_HINT 										= 1 << 4;
our $ICON_MASK_HINT 												= 1 << 5;
our $WINDOW_GROUP_HINT 											= 1 << 6;
our $MESSAGE_HINT														= 1 << 7;
our $URGENCY_HINT														= 1 << 8;

our @ALL_HINTS															= (
	$INPUT_HINT | $STATE_HINT | $ICON_PIXMAP_HINT | $ICON_WINDOW_HINT | $ICON_POSITION_HINT |
	$ICON_MASK_HINT | $WINDOW_GROUP_HINT | $MESSAGE_HINT | $URGENCY_HINT
);

our $WITHDRAWN_STATE 												= 0;
our $DONT_CARE_STATE 												= 0;
our $NORMAL_STATE 													= 1;
our $ZOOM_STATE															= 2;
our $ICONIC_STATE														= 3;
our $INACTIVE_STATE													= 4;

our $RECTANGLE_OUT													= 0;
our $RECTANGLE_IN														= 1;
our $RECTANGLE_PART													= 2;
our $VISUAL_MASK														= 0x0;
our $VISUAL_ID_MASK													= 0x1;
our $VISUAL_SCREEN_MASK											= 0x2;
our $VISUAL_DEPTH_MASK											= 0x4;
our $VISUAL_CLASS_MASK											= 0x8;

our $VISUAL_RED_MASK_MASK										= 0x10;
our $VISUAL_GREEN_MASK_MASK									= 0x20;
our $VISUAL_BLUE_MASK_MASK									= 0x40;
our $VISUAL_COLORMAP_SIZE_MASK							= 0x80;
our $VISUAL_BITS_PER_RGB_MASK								= 0x100;
our $VISUAL_ALL_MASK												= 0x1ff;

our $RELEASE_BY_FREEING_COLORMAP						= 1;
our $BITMAP_SUCCESS													= 0;
our $BITMAP_OPEN_FAILED											= 1;
our $BITMAP_FILE_INVALID										= 2;
our $BITMAP_NO_MEMORY												= 3;

our $XC_SUCCESS															= 0;
our $XC_NOMEM																= 1;
our $XC_NOENT																= 2;

# FLOAT STATES #
our $NOT_FLOATING = 1;
our $FLOATING = 2;
our $MAXIMIZED = 3;
our $FULLSCREEN = 4;
our $TOP = 5;
our $MINIMIZED = 6;

our $_NET_WM_STATE_REMOVE = 0;
our $_NET_WM_STATE_ADD = 1;
our $_NET_WM_STATE_TOGGLE = 2;

sub new {
	my ($window, $tile) = @_;
	my $hidden = True;
	my $group = undef;
	my %icons = {};
	my $x, $y, $width, $height;
	my $float_x, $float_y, $float_width, $float_height;
	my $float_info = {
		x => undef,
		y => undef,
		width => undef,
		height => undef
	};
	
	$window->set_attribute(event_mask => $self->{window_mask});

	my $g = $self->{window}->get_geometry();
	$self->{x} = $g->{x};
	$self->{y} = $g->{y};
	$self->{width} = $g->{width};
	$self->{height} = $g->{height};
	$self->{float_info}{'width'} = $g->{width};
	$self->{float_info}{'height'} = $g->{height};

	if (!$self->{x} || !$self->{y} || !$self->{width} || !$self->{height} || !$self->{float_info}{'width'}
		|| !$self->{float_info}{'height'}) {
		
		$self->{x} = undef;
		$self->{y} = undef;
		$self->{width} = undef;
		$self->{height} = undef;

		die "[!] ERROR: plwm: $!\n";
	}

	my $border_width = 0;
	my $border_color = undef;
	my $name = "<no name>";
	my $struct = undef;
	my $state = $NORMAL_STATE;
	my $float_state = $NOT_FLOATING;
	my $demands_attention = False;

	my %hints = {
		input => True,
		icon_pixmap => undef,
		icon_window => undef,
		icon_x => 0,
		icon_y => 0,
		icon_mask => 0,
		window_group => undef,
		urgent => False,
		width_inc => undef,
		height_inc => undef,
		base_width => 0,
		base_height => 0,
	}

	$self->update_hints();

	$x = $self->geometry_getter($x);
	$y = $self->geometry_getter($y);
	$width = $self->geometry_getter($width);
	$height = $self->geometry_getter($height);

	$float_x = $self->float_getter($float_x);
	$float_y = $self->float_getter($float_y);
	$float_width = $self->float_getter($float_width);
	$float_height = $self->float_getter($float_height);
}

sub has_focus {
	return $self == $self->{tile}->{current_window};
}

sub has_fixed_size {
	my $p_min_size = 'PMinSize';

	if (grep(/^$p_min_size/, $self->{hints}{'flags'}) && 
		grep(/^$p_min_size/, $self->{hints}{'flags'}) &&
		$self->{hints}{'max_width'} == $self->{hints}{'min_width'} > 0 &&
		$self->{hints}{'max_height'} == $self->{hints}{'max_height'} > 0) {
		
		return True;
	}

	return False;
}

sub hash_user_set_position {
	my $us_pos = 'USPosition';
	my $p_pos = 'PPosition';
	if (grep(/^$us_pos/, $self->{hints}{'flags'}) || grep(/^$p_pos/, $self->{hints}{'flags'})) {
		return True;
	}

	return False;
}

sub update_name {
	$self->{name} = $self->{window}->get_name() || die "[!] ERROR: plwm: $!";
	$hook->fire('client_name_updated', $self);
}

sub update_hints {
	my $h = $self->{window}->get_wm_hints() || die "[!] ERROR: plwm: $!\n";
	my $norm_h = $self->{window}->get_wm_normal_hints() || die "[!] ERROR: plwm: $!\n";
	my $urgency_hint = 'UrgencyHint'

	if (defined $norm_h) {
		$self->{hints}->update($norm_h);
	}

	if (defined $h && grep(/^$urgency_hint/, $h{'flags'})) {
		if ($self->{tile}->{current_window !~~ $self}) {
			$self->{hints}{'urgent'} = False;
			$hook->fire('client_urgent_hint_changed', $self);
		}
	} elsif (defined $self->{urgent}) {
		$self->{hints}{'urgent'} = False;
		$hook->fire('client_urgent_hint_changed', $self);
	}

	my $input_hint = 'InputHint';

	if (defined $h && grep(/^$input_hint/, $h{'flags'})) {
		$self->{hints}{'input'} = $h{'input'};
	}

	if ($self->get_group($self, undef)) {
		$self->{group}->layout_all();
	}

	return;
}

sub update_state {
	my @triggered = ('urgent');

	if (defined $self->{tile}->{config}->{auto_fullscreen}) {
		push @triggered, 'fullscreen';
	}

	my $state = $self->{window}->get_net_wm_state();
	$logger->debug("_NET_WM_STATE: $state");

	for my $s (@triggered) {
		$self->set_attr($s, grep(/^$s/, $state));
	}
}

sub urgent {
	my $val = shift;

	if (!defined $val) {
		$self->{hints}{'urgent'} = False;
	}
}

sub info {
	if ($self->{group}) {
		$group = $self->{group}->{name};
	} else {
		$group = undef;
	}

	return {
		name => $self->{name},
		x => $self->{x},
		y => $self->{y},
		width => $self->{width},
		height => $self->{height},
		group => $group,
		id => $self->{window}->{wid},
		floating => $self->{float_state} != $NOT_FLOATING,
		float_info => $self->{float_info},
		maximized => $self->{float_state} == $MAXIMIZED,
		minimized => $self->{float_state} == $MINIMIZED,
		fullscreen => $self->{float_state} == $FULLSCREEN,
	};
}

sub state {
	return $self->{window}->get_wm_state()[0];
}

sub state {
	my $val = shift;

	if (grep(/^$val/, ($WITHDRAWN_STATE, $NORMAL_STATE, $ICONIC_STATE))) {
		$self->{window}->set_property('WM_STATE', ($val, 0));
	}
}

sub set_opacity {
	my $opacity = shift;

	if ($opacity <= 1.0 && $opacity >= 0.0) {
		my $real_opacity = int($opacity * 0xffffffff);
		$self->{window}->set_property('_NET_WM_WINDOW_OPACTIY', $real_opacity);
	} else {
		return;
	}
}

sub get_opacity {
	my $opacity = $self->{window}->get_property('_NET_WINDOW_OPACITY');

	if (!defined $opacity) {
		return 1.0;
	} else {
		my $value = $opacity;
		my $as_float = round($value / 0xffffffff, 2);

		return $as_float;
	}
}

sub kill {
	my $wm_delete_window = 'WM_DELETE_WINDOW';
	if (grep(/^$wm_delete_window/, $self->{window}->get_wm_protocols())) {
		my @data = (
			$self->{tile}->{conn}->{atoms}{'WM_DELETE_WINDOW'},
			X11::Proto::Time::current_time(),
			0, 0, 0
		);

		my $u = X11:Proto::ClientMessageEvent::synthetic(@data, "I" * 5);
		my $e = X11::Proto::ClientMessageEvent::synthetic(
			format => 32,
			window => $self->{window}->{wid},
			type => $self->{tile}->{conn}->{atoms}{'WM_PROTOCOLS'},
			data => $u
		);

		$self->{window}->send_event($e);
	} else {
		$self->{window}->kill_client();
	}

	$self->{tile}->{conn}->flush();
}

sub hide {
	if ($self->disable_mask(X11::Proto::EventMask::StructureNotify)) {
		$self->{window}->unmap();
	}

	$self->{state} = $NORMAL_STATE;
	$self->{hidden} - False;
}

sub disable_mask {
	my $mask = shift;

	$self->disable_mask($mask);
	sleep 1;
	$self->reset_mask();
}
