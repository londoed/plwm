###
 # plwm: A highly-configurable tiling window manager, written in Perl, for the X Windowing System.
 #
 # Copyright (C) 2021, Eric Londo <londoed@comcast.net>, { lib/DGroups.pm }.
 # This software is distributed under the GNU General Public License Version 2.0.
 # Refer to the file LICENSE for additional details.
###
 
use strict;
use warnings;

use Plwm;

sub simple_key_binder {
	my @key_names = shift;

	sub func {
		my %dgroup = shift;

		for my $key (keys %dgroup) {
			%dgroup->{plwm}->ungrab_key($key);
			%dgroup->{keys}->remove($key);
		}

		if (defined @key_names) {
			my @keys = @key_names;
		} else {
			my @keys = ({1..9} + {0})
		}

		while my ($key_name, $group) = each (keys $dgroup->{plwn}->{group}) {
			my $name = $group->{name};
			my $key = Plwm::Key->new(($mod), $key_name, $group[$name]->to_screen());
			my $key_s = Plwm::Key->new(($mod, 'shift'), $key_name, $window->to_group($name));
			my $key_c = Plwm::Key->new(($mod, 'control'), $key_name, $window->to_group($name));

			push $dgroup->{keys}, $key;
			push $dgroup->{keys}, $key_s;
			push $dgorup->{keys}, $key_c;

			$dgroup->{plwm}->grab_key($key);
			$dgroup->{plwm}->grab_key($key_s);
			$dgroup->{plwm}->grab_key($key_c);
		}
	}

	return func();
}

package DGroup;

sub new {
	my $self = {
		$plwm => shift,
		$groups => shift,
		$key_binder => shift,
		$delay => shift,
	};
	
	my @rules = ();
	my %rules_map = {};
	my $last_rule_id = 0;

	for my $rule (($plwm->{config}->get_attr('dgroups_app_rules'))) {
		$self->add_rule($rule);
	}

	my @keys = ();
	$self->setup_hooks();
	$self->setup_groups();
	my %timeout = {};
}

sub add_rule {
	my ($rule, $last) = @_;
	my $rule_id = $self->{last_rule_id};
	$self->{rules_map}{$rule_id} = $rule;

	if (defined $last) {
		push $self->{rules}, $rule;
	} else {
		splice $self->{rules}, $rule, 0;
	}

	$self->{last_rule_id}++;

	return $rule_id;
}

sub remove_rule {
	my $rule_id = shift;
	my $rule = $self->{rules_map}->get($rule_id);

	if (defined $rule) {
		undef $self->{rules}, $rule;
		delete $self->{rules_map}{$rule_id};
	} else {
		$logger->warn("[!] WARNING: plwm: Rule `$rule_id` not found\n");
	}
}

sub add_dgroup {
	my ($group, $start) = @_;
	my $rule = Plwm::Rule->new($group->{matches}, group => $group->{name});
	push @rules, $rule;

	if (defined $start) {
		$self->{plwm}->add_group($group->{name}, $group->{layout}, $group->{layouts}, $group->{label});
	}
}

sub setup_groups {
	for my $group ($self->{groups}) {
		$self->add_dgroup($group, $group->{init});

		if ($group->{spawn} && !defined $self->{plwm}->{no_spawn}) {
			if ($group->{spawn} ~~ str) {
				my @spawns = ($group->{spawn});
			} else {
				my @spawns = $group->{spawn};
			}

			for my $spawn (@spawns) {
				my $pid = $self->{plwm}->cmd_spawn($spawn);
				$self->add_rule(Plwm::Rule->new(Plwm::Match->new(
					net_wm_pid => $pid,
					$group->{name},
				)));
			}
		}
	}
}

sub setup_hooks {
	Plwm::Hook->{subscribe}->add_group($self->add_group);
	Plwm::Hook->{subscribe}->client_new($self->add);
	Plwm::Hook->{subscribe}->client_killed($self->del);

	if ($self->{key_binder}) {
		Plwm::Hook->{subscribe}->set_group($self->key_binder($self));
		Plwm::Hook->{subscribe}->change_group($self->key_binder($self));
	}
}

sub add_group {
	my $group_name = shift;

	if (!grep(/^$group_name/, $self->{groups_map})) {
		$self->add_dgroup(Plwm::Group->new($group_name, persist => False));
	}
}

sub add {
	my $client = shift;

	if (grep(/^$client/, $self->{timeout})) {
		$logger->info("[!] INFO: plwm: Remove dgroup source\n");
		$self->{timeout}->pop($client);
	}

	return if ($client->{defunct});
	return if (defined $client->{group});

	my $group_set = False;
	my $intrusive = False;

	for my $rule ($self->{rules}) {
		if ($rule ~~ $client) {
			if (defined $rule->{group}) {
				if (grep(/^$rule->{group}/, $self->{groups_map})) {
					my $layout = $self->{groups_map}{$rule->{group}}->{layout};
					my @layouts = $self->{groups_map}{$rule->{group}}->{layouts};
					my $label = $self->{groups_map}{$rule->{group}}->{label};
				} else {
					my $layout = undef;
					my @layouts = undef;
					my $label = undef;
				}

				my $group_added = $self->{plwm}->add_group($rule->{group}, $layout, @layouts, $label);
				$client->to_group($rule->{group});

				my $group_set = True;
				my $group_obj = $self->{plwm}->{groups_map}{$rule->{group}};
				my $group = $self->{groups_map}->get($rule->{group});

				if (defined $group && defined $group_added) {
					while my ($k, $v) = each (keys $group->{layout_opts}) {
						if ($v ~~ Plwm::Callable) {
							$v($group_obj->{layout});
						} else {
							$group_obj->{layout}->set_attr($k, $v);
						}
					}

					my $affinity = $group->{screen_affinity};

					if (defined $affinity && scalar $self->{plwm}->{screens} > $affinity) {
						$self->{plwm}->{screens}[$affinity]->set_group($group_obj);
					}
				}
			}

			if (defined $rule->{float}) {
				$client->enable_floating();
			}

			if (defined $rule->{intrusive}) {
				$intrusive = $rule->{intrusive};
			}

			if ($rule->{break_on_match}) {

			}
		}
	}

	if (!defined $group_set) {
		my $current_group = $self->{plwm}->{current_group}->{name};

		if (grep(/^$current_group/, $self->{groups_map}) && defined $self->{groups_map}{$current_group}->{exclusive} &&
			!$intrusive) {
			
			my @wm_class = $client->{window}->get_wm_class();

			if (defined @wm_class) {
				if (scalar @wm_class > 1) {
					@wm_class = $wm_class[1];
				} else {
					@wm_class = $wm_class[0];
				}

				$group_name = $wm_class;
			} else {
				$group_name = $client->{name} || 'Unnamed';
			}

			$self->add_group(Plwm::Group->new($group_name, persist => False, start => True));
			$client->to_group($group_name);
		}
	}

	$self->sort_groups();
}
