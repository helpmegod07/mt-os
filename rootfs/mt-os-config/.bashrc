export TERM=xterm-256color
[ -f /etc/mt-os/api.env ] && export $(cat /etc/mt-os/api.env)
export PS1='\[\033[01;32m\]👻 ghost\[\033[0m\]:\[\033[01;36m\]\w\[\033[0m\]\$ '
ghost() {
    [ -z "$1" ] && { echo "Usage: ghost <word>"; return; }
    python3 -c "
import json,subprocess
d=json.load(open('/etc/mt-os/ghost-commands.json'))
w='$1'
if w in d: [subprocess.run(c,shell=True) for c in d[w]]
else: print(f'No ghost command: {w}')
"
}
ghost-add() {
    local w="$1"; shift; local c="$*"
    python3 -c "
import json
d=json.load(open('/etc/mt-os/ghost-commands.json'))
d['$w']=[x.strip() for x in '$c'.split('|')]
json.dump(d,open('/etc/mt-os/ghost-commands.json','w'),indent=2)
print('Saved.')
"
}
ghost-list() {
    python3 -c "
import json
d=json.load(open('/etc/mt-os/ghost-commands.json'))
[print(f'  ghost {k} -> {\" | \".join(v)}') for k,v in d.items()] if d else print('No commands.')
"
}
alias ll='ls -lah --color=auto'
alias ..='cd ..'
alias mt-face='python3 /opt/mt-os/mt-face.py &'
alias mt-term='python3 /opt/mt-os/mt-terminal.py &'
alias mt-display='python3 /opt/mt-os/mt-display.py'
alias mt-ghost='python3 /opt/mt-os/mt-ghost-manager.py'
alias mt-install='sudo bash /opt/mt-os/mt-install.sh'
alias mt-apikey='bash /opt/mt-os/mt-apikey.sh'
echo ""
echo "  👻  MT-OS — Ghost ready."
echo ""
