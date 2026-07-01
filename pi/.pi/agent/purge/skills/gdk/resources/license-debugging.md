# License Debugging in GDK

## Customers Portal URL

GDK (dev/test env) defaults to **staging**: `https://customers.staging.gitlab.com`

Configured in: `gitlab/config/routes/directs/subscription_portal.rb`

Override with env vars:
- `CUSTOMER_PORTAL_URL` — overrides the portal URL entirely
- `STAGING_CUSTOMER_PORTAL_URL` — overrides the staging URL

Verify current URL:
```bash
echo 'puts Gitlab::Routing.url_helpers.subscription_portal_graphql_url' | gdk rails console
```

## Activation Code

Activation codes must match the portal environment — a staging code won't work against production and vice versa.

## Debugging Activation Failures

### Key log files

- `gitlab/log/development_json.log` — look for `activateSubscription` operation
- `gitlab/log/graphql_json.log` — GraphQL details
- `gitlab/log/exceptions_json.log` — exceptions during activation

### Signs of failure in logs

- `activateSubscription` requests with `db_write_count: 0` → license wasn't saved
- Very fast response times (< 5ms) with 0 writes → request likely failed before reaching CustomersDot
- HTTP 200 doesn't mean success — GraphQL errors are in the response payload

### Test activation via rails console

```ruby
result = GitlabSubscriptions::ActivateService.new.execute("YOUR_ACTIVATION_CODE")
puts result.inspect
# success: true  → license activated
# success: false → check result[:errors]
```

### Relevant code

- Mutation: `ee/app/graphql/mutations/gitlab_subscriptions/activate.rb`
- Service: `ee/app/services/gitlab_subscriptions/activate_service.rb`
- CustomersDot client: `ee/lib/gitlab/subscription_portal/clients/graphql.rb` (the `activate` method)
- Portal URL routing: `config/routes/directs/subscription_portal.rb`

### Check current license state

```ruby
# Rails console
License.current          # current active license
License.current&.plan    # plan name (ultimate, premium, etc.)
License.current&.expired? # expiration check
```

```sql
-- Via gdk psql
SELECT id, cloud, created_at, last_synced_at FROM licenses ORDER BY id DESC LIMIT 5;
SELECT encrypted_cloud_license_auth_token IS NOT NULL as has_token FROM application_settings LIMIT 1;
```
