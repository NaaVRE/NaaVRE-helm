{{/*
Expand the name of the chart.
*/}}
{{- define "values.name" -}}
{{- default "naavre" .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "values.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default "naavre" .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{- define "naavre_requirements_hash" }}
{{- printf "%s" (.Values.binderhub.builder.naavre_requirements | toJson | sha256sum | trunc 8) }}
{{- end }}

{{- define "naavre_catalogue_lookup_py" }}
import json
from tornado.httpclient import AsyncHTTPClient, HTTPRequest

async def get_objects_from_catalogue(path):
  url = "https://{{ .Values.global.ingress.domain }}/{{ trimAll "/" .Values.naavreCatalogueService.ingress.basePath }}" + path
  skip_verify_ssl = {{ .Values.global.insecureSkipVerifySSL | ternary "True" "False" }}
  client = AsyncHTTPClient()
  results = []
  next_url = url
  while next_url:
    request = HTTPRequest(
        url=next_url,
        method='GET',
        headers={'Accept': 'application/json'},
        validate_cert=not skip_verify_ssl,
    )
    response = await client.fetch(request, raise_error=True)
    payload = json.loads(response.body)
    results += payload.get('results', [])
    next_url = payload.get('next')
  return results

def binder_refs_match(ref_a, ref_b):
  # Binder refs are of the form {provider_prefix}/{spec}
  provider_a, spec_a = ref_a.split('/', 1)
  provider_b, spec_b = ref_b.split('/', 1)
  if provider_a != provider_b:
    return False
  if provider_a == 'gh':
    # For GitHub providers, specs are of the form
    # 'gh/<user>/<repo>/<commit-sha-or-tag-or-branch>'.
    # Match based on user and repo, regardless of the
    # commit-sha-or-tag-or-branch.
    user_repo_a, _ = spec_a.rsplit('/', 1)
    user_repo_b, _ = spec_b.rsplit('/', 1)
    return user_repo_a == user_repo_b
  else:
    # For other providers, match based on the full spec
    return spec_a == spec_b

async def find_labs(binder_ref):
  binder_envs_urls = [
    env['url'] for env in await get_objects_from_catalogue('/binder-environments/')
    if binder_refs_match(env['binder_ref'], binder_ref)
  ]
  return [
    lab for lab in await get_objects_from_catalogue('/virtual-labs/')
    if lab.get('binder_environment') in binder_envs_urls
  ]
{{- end }}
