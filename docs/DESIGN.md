# .github Repository Design

## Purpose

Organization-level GitHub configuration and branding for the Plures ecosystem. This repo provides:

1. **Public Profile** - Organization README and branding
2. **Workflow Templates** - Standardized CI/CD templates for repos
3. **Issue/PR Templates** - Consistent contribution guidelines
4. **Organization Defaults** - Security policies, branch protection

## Current Architecture

### Brand Identity
- **Messaging**: Practical tools for network operations, local memory and accountable automation for LLMs and agents
- **Visual**: SVG assets in `/assets/images/`
- **Tone**: Useful, careful and collaborative; people keep control of their tools and data

### Workflow Templates
- Located in `/workflow-templates/`
- Provides templates for new repos to adopt consistent CI/CD
- Currently minimal - needs expansion

### Profile Content
- `/profile/README.md` - Public org profile based on the approved identity and PX public projection
- Main `/README.md` - Same approved identity and public projection for repository visitors

## Design Issues & Improvements

### 1. **Messaging Alignment** ✅
**Status**: Completed — branding now emphasizes practical tools for network operations, local memory and accountable automation across the org profile and all public-facing docs.

**Current positioning**:
- "More, together."
- Practical tools for network operations, local memory and accountable automation
- People keep control of their tools and data

### 2. **Workflow Template Gaps**
**Problem**: Most repos create CI from scratch instead of inheriting org templates.

**Needed Templates**:
- Node.js/TypeScript with npm publishing
- Rust crate with Cargo publishing
- GitHub Package publishing 
- Security scanning (CodeQL, dependency review)
- Auto-labeling and issue triage

### 3. **Asset Organization**
**Problem**: SVG assets are present but may not align with new brand direction.

**Improvements**:
- Update color schemes for Pares branding
- Add logo variants for different contexts
- Ensure accessibility compliance

### 4. **Documentation Standards**
**Problem**: No standardized repo documentation templates.

**Solution**: Add templates for:
- Standard README structure
- CONTRIBUTING.md guidelines
- Security policy templates
- Code of conduct

## Next Implementation Phase

1. **Brand Refresh** ✅ - Messaging realigned to the approved Plures identity
2. **Template Library** - Comprehensive workflow templates for common patterns
3. **Documentation Templates** - Standard repo documentation structure
4. **Security Hardening** - Org-level security policies and templates

## Dependencies

- Development Guide standards (publish as GitHub Package first)
- Pares marketing strategy finalization
- Asset refresh from design team