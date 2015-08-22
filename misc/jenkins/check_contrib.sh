#!/bin/bash
# This file is part of NIT ( http://www.nitlanguage.org ).
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Check the build and the execution of software in lib/, examples/ and contrib/
# The script must be run from the root Nit directory.
#
# various .xml junit file will be generated in the root directory for jenkins.
#
# Arguments will be additional `make` rules to execute. eg.
#
#     check_contrib.sh check android

projects=`echo lib/*/Makefile examples/*/Makefile contrib/*/Makefile`
rules=$*

failed=
for p in $projects; do
	dir=`dirname "$p"`
	name=`basename "$dir"`
	echo "*** make $dir ***"
	if misc/jenkins/unitrun.sh "cmd-$name-make" make -C "$dir"; then
		# Make OK. Check additional rules if they exists
		for rule in $rules; do
			make -C "$dir" $rule -n 2>/dev/null ||
				continue
			echo "*** make$rule $dir ***"
			misc/jenkins/unitrun.sh "cmd-$name-make$rule" make -C "$dir" $rule ||
				failed="$failed $name-$rule"
		done
	else
		failed="$failed $name"
	fi
done
grep '<error message' *-make*.xml
if test -n "$failed"; then
	echo "FAILED: $failed"
	exit 1
fi
exit 0
