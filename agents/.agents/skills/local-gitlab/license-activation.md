# License activation on Caproni instances

The stock chart instances are unlicensed. Duo Enterprise (workflows, agent platform,
AI catalog) needs an EE Ultimate license **plus** a `duo_enterprise` add-on purchase,
so activate before any Duo testing. Recorded here after doing it manually on both
instances on 2026-11-10.

## Where the activation code lives

1Password, account `gitlab.1password.com`, vault **Engineering**, item
**`GitLab_self_managed_ultimate_Duo_enterprise`**, field `activation_code`
(a ~3 KB single-line JWT). Tomas can paste it to a file (e.g. `/tmp/activation`)
instead of signing `op` in — that is often the fastest path for agents.

## Automatic path (edit mode only)

`repos/gitlab/.gitlab/caproni/activate-license.sh` (an `edit_mode_start` hook) fetches
the code from 1Password and activates via a mirrord Rails runner. Requirements:

- `op` signed in (`op signin --account gitlab.1password.com` — biometric, only Tomas).
- `CAPRONI_ACTIVATE_LICENSE=1` (else the hook skips; `0` skips explicitly).

The hook is fatal on 1Password failure *for its own sake*, but
`setup-ai-gateway.sh` calls it with `|| true`, so `caproni run` continues either way —
the license just stays inactive. With no `op` session the hook may pop a biometric
prompt on Tomas's screen before failing.

## Manual path (works on stock instances too, no op needed)

Activate directly in the toolbox pod. Idempotent, safe to re-run, and it does the
same three things the hook does: cloud license, `duo_enterprise` add-on purchase,
root user add-on assignment.

Gotcha: `kubectl exec` has **no `--env` flag** — pass the script (with the code
embedded) via stdin instead:

```bash
ACT=$(cat /tmp/activation)
cat > /tmp/activate-license.rb <<EOF
begin
  activation_code = <<'CODE'
\$ACT
CODE
  activation_code = activation_code.strip
  if License.current&.cloud?
    puts "already: #{License.current.plan}"
  else
    license = License.create!(data: activation_code.gsub("\\\\n", "\n"), cloud: true)
    puts "activated: #{license.plan}, expires #{license.expires_at}"
  end
  add_on = GitlabSubscriptions::SystemDefined::AddOn.find_by!(name: 'duo_enterprise')
  ap = GitlabSubscriptions::AddOnPurchase.find_or_create_by!(subscription_add_on_uid: add_on.id) do |p|
    p.quantity = 1
    p.started_at = License.current.starts_at || Date.current
    p.expires_on = License.current.expires_at
    p.purchase_xid = "caproni-manual-#{Time.now.to_i}"
    p.organization_id = Organizations::Organization.first&.id
  end
  root_user = User.find_by_username('root')
  GitlabSubscriptions::UserAddOnAssignment.find_or_create_by!(add_on_purchase: ap, user: root_user) if root_user
  puts "SUCCESS"
rescue StandardError => e
  puts "ERROR: #{e.message}"
end
EOF
for CTX in caproni-a caproni-b; do
  kubectl --context $CTX exec -i deploy/gitlab-toolbox -c toolbox -- \
    gitlab-rails runner -e production - < /tmp/activate-license.rb
done
rm /tmp/activate-license.rb
```

(heredoc-in-heredoc: the inner `\$ACT` is expanded by the outer shell when the file
is written, so the code lands in the script, not on any command line.)

## Notes

- Activation is pure DB state: it survives `caproni run`, migrations and redeploys,
  but not `caproni destroy`. Re-run after a rebuild.
- No `SeatLinkData.sync` in the manual path (the hook does it best-effort; it needs
  network to CustomerDot and is non-fatal there too).
- Check state: `License.current.plan` and
  `GitlabSubscriptions::AddOnPurchase.where(subscription_add_on_uid: GitlabSubscriptions::SystemDefined::AddOn.find_by(name: 'duo_enterprise').id).count`
  in any Rails runner.
- If the AIGW setup script seeds Duo *before* you activate, re-run the seeding steps
  (or the whole script with `CAPRONI_DUO_SETUP_FORCE=1`) afterwards; some rake tasks
  behave differently without a license.
