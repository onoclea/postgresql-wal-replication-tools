#!/bin/bash

RECOVERY_TRIGGER="/var/lib/pgsql/data/recovery.trigger"
RECOVERY_PREFIX="/var/lib/pgsql/data/recovery"
RECOVERY_CONF="$RECOVERY_PREFIX.conf"
RECOVERY_DONE="$RECOVERY_PREFIX.done"

for s in `seq 60`; do
	echo -n "Checking db cluster status: " >&2

	perl -MIO::Socket::INET -e 'exit (new IO::Socket::INET(LocalAddr => "db") ? 0 : 1)';

	IS_MASTER=$?

	if [ $IS_MASTER -eq 0 ]; then
		if [ -f $RECOVERY_CONF -a ! -f $RECOVERY_TRIGGER ]; then
			echo "elected as master." >&2
			logger -it "db_check" "Elected as master."

			touch $RECOVERY_TRIGGER
		else
			echo "master." >&2
		fi
	else
		if [ ! -f $RECOVERY_CONF ]; then
			echo "demoted to slave." >&2
			logger -ist "db_check" "Demoted to slave."

			service postgresql status | grep "is stopped$" 1>&2 2>/dev/null
			IS_STOPPED=$?

			if [ $IS_STOPPED -ne 0 ]; then
				if [ -x /usr/bin/monit ]; then
					monit stop postgresql 1>/dev/null
				fi

				service postgresql stop 1>/dev/null
			fi

			mv -f $RECOVERY_DONE $RECOVERY_CONF
		else
			echo "slave." >&2
		fi
	fi

	sleep 1
done
