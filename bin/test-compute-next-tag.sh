#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Slavi Pantaleev
#
# SPDX-License-Identifier: AGPL-3.0-or-later

# Exercises bin/compute-next-tag.sh against throwaway git repositories.
#
# Usage: bin/test-compute-next-tag.sh
#
# Every scenario creates a repository in a temporary directory, gives it role
# files and a release history, and then replays a series of merges through the
# real script, tagging as it goes just like the autotag workflow does. This
# repository is never touched and no network access is needed.

set -euo pipefail

script_under_test="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/compute-next-tag.sh"

failures=0
workdir=''

cleanup() {
	cd /
	if [ -n "$workdir" ]; then
		rm -rf "$workdir"
		workdir=''
	fi
}

trap cleanup EXIT

# Starts a scenario with a repository at CouchDB 3.5.2 which has already seen
# three releases of it (v3.5.2-0, v3.5.2-1 and v3.5.2-2), plus the older
# v3.5.1-x line, exactly like this repository's real tag history.
#
# The defaults file carries the traps this role's real one has: the Renovate
# annotation that has to stay on the line the script reads, an image tag
# derived from the version through Jinja, and a `couchdb_connection_port`
# whose name also starts with `couchdb_`. None of them may be read as the
# version.
scenario() {
	echo "$1"

	cleanup
	workdir="$(mktemp -d)"

	mkdir -p "$workdir/bin" "$workdir/defaults" "$workdir/meta" "$workdir/tasks" "$workdir/templates"
	cp "$script_under_test" "$workdir/bin/"
	cd "$workdir"

	git init -q -b main .
	git config user.email 'test@example.com'
	git config user.name 'Test'
	git config commit.gpgsign false

	cat > defaults/main.yml <<-'YAML'
		# renovate: datasource=docker depName=library/couchdb versioning=semver
		couchdb_version: 3.5.2

		couchdb_container_image: "{{ couchdb_container_image_registry_prefix }}couchdb:{{ couchdb_container_image_tag }}"
		couchdb_container_image_tag: "{{ couchdb_version }}"

		couchdb_connection_port: 5984
	YAML
	printf 'placeholder\n' > meta/main.yml
	printf 'placeholder\n' > tasks/main.yml
	printf 'placeholder\n' > templates/local.ini.j2
	printf 'placeholder\n' > README.md

	git add -A
	git commit -qm 'Initial commit'

	local tag
	for tag in v3.5.1-0 v3.5.1-1 v3.5.2-0 v3.5.2-1 v3.5.2-2; do
		git tag "$tag"
	done
}

# Applies a change, commits it, and tags whatever the script says it should be.
# Prints the tag, or nothing when the script decided against a release.
merge() {
	local change="$1" tag

	eval "$change"
	git add -A
	git commit -qm 'Merge'

	tag="$(bin/compute-next-tag.sh 2>/dev/null)"

	if [ -n "$tag" ]; then
		git tag "$tag"
	fi

	printf '%s' "$tag"
}

expect() {
	local description="$1" expected="$2" actual="$3"

	if [ "$actual" = "$expected" ]; then
		printf '  ok   | %s -> %s\n' "$description" "${actual:-no release}"
	else
		printf '  FAIL | %s -> expected %s, got %s\n' "$description" "${expected:-no release}" "${actual:-no release}"
		failures=$((failures + 1))
	fi
}

bump_version="sed -i 's|^couchdb_version: 3.5.2|couchdb_version: 3.5.3|' defaults/main.yml"
revert_version="sed -i 's|^couchdb_version: 3.5.3|couchdb_version: 3.5.2|' defaults/main.yml"
bump_minor="sed -i 's|^couchdb_version: 3.5.2|couchdb_version: 3.6.0|' defaults/main.yml"
edit_annotation="sed -i 's|versioning=semver|versioning=docker|' defaults/main.yml"
edit_meta="printf 'a line\n' >> meta/main.yml"
edit_task="printf 'a task\n' >> tasks/main.yml"
edit_template="printf 'a line\n' >> templates/local.ini.j2"
edit_readme="printf 'documentation\n' >> README.md"
edit_script="printf '# a comment\n' >> bin/compute-next-tag.sh"

# The two merge orders below apply the same updates and must each end up with
# every update released exactly once, whichever order they arrive in.

scenario 'A version bump merged before other role changes'
expect 'version bump' v3.5.3-0 "$(merge "$bump_version")"
expect 'task edit'    v3.5.3-1 "$(merge "$edit_task")"
expect 'template'     v3.5.3-2 "$(merge "$edit_template")"

scenario 'A version bump merged after other role changes'
expect 'task edit'    v3.5.2-3 "$(merge "$edit_task")"
expect 'version bump' v3.5.3-0 "$(merge "$bump_version")"

# The tag line for the previous minor exists throughout. Continuing its counter
# instead of starting a fresh one would republish a version that is no longer
# what defaults/main.yml points at.
scenario 'A minor bump does not continue the previous version line'
expect 'minor bump' v3.6.0-0 "$(merge "$bump_minor")"
expect 'task edit'  v3.6.0-1 "$(merge "$edit_task")"

# `couchdb_container_image_tag` is a `_tag` line derived from the version, and
# `couchdb_connection_port` starts with the same prefix as the version
# variable. Reading either of them would produce a nonsense tag, so a refactor
# that loosens the anchor has to fail here.
scenario 'The derived image tag is not mistaken for the version'
expect 'a task' v3.5.2-3 "$(merge "$edit_task")"

# The `# renovate:` annotation and `couchdb_version` have to stay adjacent:
# Renovate's custom manager matches the annotation followed by the version
# line, and this script reads the same line. Editing the annotation alone is a
# defaults change and therefore release-worthy, but must not shift the version.
scenario 'An edit of the Renovate annotation'
expect 'annotation' v3.5.2-3 "$(merge "$edit_annotation")"

scenario 'Commits that do not affect the role'
expect 'README'   ''        "$(merge "$edit_readme")"
expect 'a script' ''        "$(merge "$edit_script")"
expect 'meta'     v3.5.2-3  "$(merge "$edit_meta")"

scenario 'Release numbers past 9'
for release_number in 3 4 5 6 7 8 9 10; do
	git tag "v3.5.2-$release_number"
done
expect 'a task' v3.5.2-11 "$(merge "$edit_task")"

scenario 'Reverting to an already released version'
merge "$bump_version" > /dev/null
# The role is now identical to what v3.5.2-2 already published, so there is
# nothing new to release.
expect 'a revert' ''        "$(merge "$revert_version")"

scenario 'Reverting to an already released version, with a change'
merge "$bump_version" > /dev/null
expect 'a revert' v3.5.2-3 "$(merge "$revert_version && $edit_task")"

if [ "$failures" -gt 0 ]; then
	echo >&2 "$failures scenario(s) behaved unexpectedly"
	exit 1
fi

echo 'All scenarios behaved as expected'
