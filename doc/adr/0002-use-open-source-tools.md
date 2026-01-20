# 2. Use Open Source Tools

Date: 2026-01-20

## Status

Accepted

## Context

We need to manage cloud resources for the project. There are several tools available, such as Terraform and OpenTofu. We prefer to use open source solutions where possible to avoid vendor lock-in and support the open source community.

## Decision

We will use Open Source tools whenever possible. Specifically, we will use OpenTofu instead of Terraform for Infrastructure as Code (IaC).

## Consequences

- We can use OpenTofu which is a fork of Terraform and is open source.
- We avoid potential licensing changes or restrictions from proprietary tools.
- We might need to ensure compatibility with Terraform providers, which OpenTofu generally supports.
- We need to use `tofu` command instead of `terraform`.
