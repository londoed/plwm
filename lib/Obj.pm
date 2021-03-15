###
 # plwm: A highly-configurable tiling window manager, written in Perl, for the X Windowing System.
 #
 # Copyright (C) 2021, Eric Londo <londoed@comcast.net>, { lib/Obj.pm }.
 # This software is distributed under the GNU General Public License Version 2.0.
 # Refer to the file LICENSE for additional details.
###

package Obj;

sub new {
	$self = {
		name => shift,
	};
}

sub str {
	return $self->{name};
}

