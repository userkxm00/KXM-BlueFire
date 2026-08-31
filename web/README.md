# KXM BlueFire Web

This directory is the source for the public KXM BlueFire website and private admin dashboard.

## Design direction

Inspired by the provided Taste Skill reference: editorial/product-marketing presentation, strong art direction, deliberate typography, high-quality motion, and anti-template discipline. The project also follows UI UX Pro Max principles: responsive behavior, accessible interactions, explicit states, resilient text, and evidence-driven component choices.

Reference projects:
- https://github.com/Leonxlnx/taste-skill
- https://github.com/nextlevelbuilder/ui-ux-pro-max-skill

Do not copy proprietary assets or source code from those projects. This site uses their public design methodology as inspiration and keeps KXM-specific implementation original.

## Planned sections

- Public landing page
- Download / releases
- Documentation
- BlueStacks + Free Fire profiles
- Community statistics
- Privacy / telemetry policy
- Changelog
- Admin dashboard
- Recommendation review queue
- Community analytics
- Profile/rule publishing

## Security boundary

Browser code must never receive the Supabase secret key. Only the public publishable key may be exposed to client-side code, and only with appropriate RLS. Admin actions must run server-side and require authentication/authorization.
