#!/bin/bash

helm dependency build drupal
helm package drupal --destination docs

helm dependency build cornerstone
helm package cornerstone --destination docs

helm dependency build signet
helm package signet --destination docs

helm repo index docs --url https://lestatv.github.io/charts/
