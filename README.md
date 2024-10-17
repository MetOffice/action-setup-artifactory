# Setup Artifactory Action
Github action to configure connection to Met Office Artifactory for a workflow job.

The action writes the following files to the Github runner to enable
communication with Artifactory for Python:

|File                        |Reason                                                        |
| -------------------------- | ------------------------------------------------------------ |
| ``~/.netrc``               | Add the provided Artifactory credentials                     |
| ``~/condarc``              | Add the ``channel_alias`` to point to Artifactory for conda. |
| ``~/.config/pip/pip.conf`` | Add the ``index-url`` to point to Artifactory for pip.       |


Usage
-----

```yaml
- uses: MetOffice/action-setup-artifactory@v1
  with:
    # Artifactory username. This is usually a user/team email address
    # Default: ${{ secrets.ART_USER}}
    username: ''

    # Artifactory API key. This can be obtained by logging into Artifactory
    # with either username/password or SSO.
    # Default: ${{ secrets.ART_KEY}}
    api-key: ''
```

Examples
--------

Configure Artifactory using github secrets `ART_USER` and `ART_KEY`:

```yaml
jobs:
  my-job:
    steps:

        # Using default secrets for this action, so no need to specify
        # username or api-key
      - name: Set up Artifactory connection
        uses: MetOffice/action-setup-artifactory@v1

      - name: Set up Python
        uses: actions/setup-python@v2
        with:
          python-version: "3.8"

      - name: Install Package from Artifactory
        run: pip install some-package-on-artifactory
```

Configure Artifactory using differently named github secrets:

```yaml
jobs:
  my-job:
    steps:
        # Specifying username and api key
      - name: Set up Artifactory connection
        uses: MetOffice/action-setup-artifactory@v1
        with:
          username: ${{ secrets.USERNAME }}
          api-key: ${{ secrets.API_KEY }}

      - name: Set up Python
        uses: actions/setup-python@v2
        with:
          python-version: "3.8"

      - name: Install Package from Artifactory
        run: pip install some-package-on-artifactory
```
