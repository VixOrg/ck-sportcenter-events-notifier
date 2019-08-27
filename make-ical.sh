#!/usr/bin/env bash
set -e

dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd $dir

cookie=$(curl -vs -X POST -d "action=logIn&`head -1 .auth`" "https://ssl.forumedia.eu/ck-sportcenter.lu/login.php" 2>&1 | grep -F 'Set-Cookie' | awk '{print $3}')
curl -s -H "Cookie: $cookie" 'https://ssl.forumedia.eu/ck-sportcenter.lu/clients_reservations.php' > /tmp/badminton.out

# Convert HTML output to JSON
echo '[' >/tmp/badminton.json

cat /tmp/badminton.out | grep -E '^(<tr|</tr>|<td>)' | grep -vE '(nbsp|Badminton|GH|\[SY\])' | sed -E 's/<tr.+>/{/g;s/.+tr>/},/g;s/<.?td>//g;s/([0-9]{2}.[0-9]{2}.[0-9]{4})/"date": "\1",/g;s/([0-9]{2}:[0-9]{2}) -/"start": "\1",/g;s/ [0-9]{2}:[0-9]{2}//g;s/(Court.+)/"title": "\1"/g;s/^([^"}{].+)/,"description": "\1"/g;' | tail -n +3 >>/tmp/badminton.json

echo "{}]" >>/tmp/badminton.json

# Prepare ICAL template
cat >/tmp/badminton.ical <<EOF
BEGIN:VCALENDAR
VERSION:2.0
PROID:-//Gems//Kockelshoer Fetcher 0.1/EN
CALSCALE:GREGORIAN
METHOD:PUBLISH
EOF

export LC_ALL=en_US.UTF-8
export TZ=CET

function get-uid() {
  echo "${1}" | md5sum | tr '[:lower:]' '[:upper:]' | awk '{print substr($1,1,8) "-" substr($1,9,4) "-" substr($1,13,4) "-" substr($1,17,4) "-" substr($1,21)}'
}

function get-datetime() {
  local d=`echo ${1} | awk -F . '{print $1}'`
  local m=`echo ${1} | awk -F . '{print $2}'`
  local y=`echo ${1} | awk -F . '{print $3}'`
  local hh=`echo ${2} | awk -F : '{print $1}'`
  local mm=`echo ${2} | awk -F : '{print $2}'`
  local ss=`echo ${2} | awk -F : '{print $3}'`

  local date=`date -d "${hh}:${mm}:${ss:-00} ${y}-${m}-${d}"`
  date -u -d "${date} ${4}" ${3}
}

function compose-icalevent() {
  while IFS='%' read -r title date time desc; do
    local uid=`get-uid "event-${date}-${time}"`
    local start_date=`get-datetime ${date} ${time} +%Y%m%dT%H%M%SZ`
    local end_date=`get-datetime ${date} ${time} +%Y%m%dT%H%M%SZ '+1 hour'`
    local description=`./namer.py ${uid}`

    local curr_date=`date -u +%s`
    local event_date=`get-datetime ${date} ${time} +%s`

    if [ $curr_date -ge $event_date ]; then
      continue
    fi

    local event=`gcalcli --nocolor --calendar Badminton search "${description}" | tr -d '\n' | grep -vFi 'No events'`

    if [ -n "${event}" ]; then
      local found_date=`date -d "$(echo "${event}" | awk '{print $1 " " $2}')" +%s`
      local found_title="${event:20}"

      if [ $found_date -eq $event_date ] && [ "${title}" = "${found_title}" ]; then
        continue
      fi

      gcalcli --calendar Badminton delete "${description}" --iamaexpert >&2
    fi

    printf "\
BEGIN:VEVENT\n\
SUMMARY:${title}\n\
DESCRIPTION:${description}\n\
UID:${uid}\n\
SEQUENCE:0\n\
DTSTART:${start_date}\n\
DTEND:${end_date}\n\
`cat ical.tmpl`
LOCATION: 20 Route de Bettembourg, 1899 Kockelscheuer\n\
GEO:49.5626814;6.1082521\n\
CLASS:CONFIDENTIAL\n\
CATEGORIES:SPORT,PERSONAL\n\
END:VEVENT\n"
 
  done <&0
}

cat /tmp/badminton.json | jq --raw-output '.[] | "\(.title)%\(.date)%\(.start)%\(.description)"' | grep -vE '^null' | compose-icalevent >>/tmp/badminton.ical

cat >>/tmp/badminton.ical <<__EOF
END:VCALENDAR
__EOF

echo "Make ICAL: done"

