#!/bin/bash

helm dependency build drupal
helm package drupal --destination docs

helm package simple --destination docs

helm repo index docs --url https://lestatv.github.io/charts/
