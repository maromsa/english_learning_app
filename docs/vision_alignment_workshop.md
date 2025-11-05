### Vision & Alignment Workshop Brief

**Purpose**
- Align product, design, engineering, data, and go-to-market stakeholders on target users, core value propositions, success metrics, and MVP scope for the AI-driven learning app.
- Produce tangible artifacts (personas, value-prop canvas, metrics tree, MVP definition) to guide subsequent roadmap execution.

**Desired Outcomes**
- Shared understanding of priority user segments and their jobs-to-be-done.
- Agreement on differentiating AI capabilities and corresponding risks/assumptions.
- Draft success metrics framework with owners and instrumentation status.
- MVP pillars, guardrails, and must-have features documented with decision rationale.

**Participants & Roles**
| Role | Primary Contact | Responsibilities |
| --- | --- | --- |
| Executive Sponsor | _TBD (e.g., Head of Product)_ | Frame strategic context, approve scope and success criteria. |
| Product Lead | _TBD_ | Facilitate workshop, synthesize decisions into roadmap inputs. |
| Engineering Lead | _TBD_ | Validate technical feasibility, surface architectural considerations. |
| Design/UX Lead | _TBD_ | Represent user insights, prototype constraints, accessibility needs. |
| Data/AI Lead | _TBD_ | Articulate AI differentiators, data requirements, and risks. |
| Marketing/Growth | _TBD_ | Connect positioning, acquisition channels, pricing assumptions. |
| Compliance/Legal | _TBD_ | Highlight privacy, safety, and policy obligations. |

**Pre-Work & Inputs**
- Collect existing user research, analytics, and competitive analysis (owner: Product Research).
- Summarize current app telemetry, crash data, and retention metrics (owner: Data).
- Inventory AI capabilities, training datasets, and limitations (owner: Data/AI Lead).
- Draft initial personas (2–3) and use-case maps based on available insights (owner: UX Research).
- Compile business model hypotheses, pricing experiments, and historical revenue performance (owner: Marketing/Growth).

**Workshop Agenda (Suggested 3 hours)**
| Time | Topic | Owner | Output |
| --- | --- | --- | --- |
| 0:00 – 0:15 | Context & Objectives | Executive Sponsor | Shared success definition |
| 0:15 – 0:45 | User & Market Insights | Design/UX | Persona draft validation |
| 0:45 – 1:15 | AI Differentiators & Risks | Data/AI | Differentiator list with risk log |
| 1:15 – 1:25 | Break | — | — |
| 1:25 – 2:00 | Success Metrics Tree | Product/Data | Metrics framework & ownership |
| 2:00 – 2:40 | MVP Scope & Guardrails | Product/Engineering | MVP pillars & out-of-scope list |
| 2:40 – 3:00 | Next Steps & Owners | Product Lead | Action register & follow-ups |

**Candidate Feature Themes for MVP Discussion**
- **Onboarding & Personalization**: Adaptive onboarding quiz, AI-generated learning paths, profile-based daily goals.
- **Core Gameplay Loop**: Map-based level progression, timed image quizzes, contextual hints, adaptive difficulty ramps.
- **AI-Powered Validation**: Real-time user image assessment, feedback explanations, confidence scoring with retry guidance.
- **Reward Economy**: Daily streak bonuses, coin rewards, unlockable power-ups (e.g., clue reveals, time extensions), shop inventory tied to progress.
- **Social & Accountability**: Friend leaderboards, weekly challenges, shareable progress cards, opt-in study groups.
- **Content Expansion**: Dynamic level packs, seasonal events, vocabulary expansions, educator-curated playlists.
- **Engagement & Retention Hooks**: Push notifications for streak protection, in-app tips from AI coach, milestone celebrations.
- **Analytics & Telemetry**: In-app feedback prompts, session recording toggles, funnel tracking for onboarding and core loops.
- **Safety & Compliance**: Content moderation dashboard, parental controls, GDPR/CCPA consent flows.

**Artifacts to Capture During Session**
- Persona summaries with pains/gains and prioritized journeys.
- Value proposition canvas highlighting AI-enabled advantages.
- Metrics tree covering acquisition, activation, engagement, retention, monetization, with instrumentation status.
- MVP definition sheet including must-have features, success criteria, dependencies, and out-of-scope decisions.
- Risk & assumption log with validation plan.

**Success Metrics Framework (Draft)**
| Funnel Stage | North-Star Metric | Supporting Metrics | Instrumentation Status |
| --- | --- | --- | --- |
| Acquisition | New activated users / week | Install-to-onboard rate, CAC by channel | Verify Firebase attribution setup |
| Activation | Onboarding completion rate | Time-to-complete onboarding, drop-off screen index | Map analytics events `onboarding_step_*` |
| Engagement | Weekly active learners | Average sessions/week, quiz completion %, hint usage | Ensure session tracking + quiz events |
| Retention | D30 retention | Streak adherence %, notification opt-in rate | Confirm push notification analytics |
| Monetization | ARPDAU | Conversion to paid bundle, average order value | Validate in-app purchase reporting |

**Assumption & Risk Starter List**
- AI image validation accuracy meets user expectations across age segments (risk: false negatives erode trust).
- Content sourcing can scale without IP/licensing issues (risk: legal exposure, delays).
- Daily streak mechanic drives retention without fatigue (risk: push notifications ignored -> churn).
- Cloud costs remain manageable with projected MAU growth (risk: margin pressure, require optimization).
- Compliance review can be completed pre-launch for target geos (risk: delayed go-to-market).

**Action Register Template**
| Action | Owner | Due Date | Status | Notes |
| --- | --- | --- | --- | --- |
| Capture finalized personas | Design/UX | _TBD_ | Not started | Populate Figma board |
| Audit AI model training data | Data/AI | _TBD_ | Not started | Confirm diversity coverage |
| Draft MVP sprint plan | Product | _TBD_ | Not started | Align with engineering capacity |
| Validate legal/compliance requirements | Compliance | _TBD_ | Not started | Schedule review with counsel |
| Instrument metrics events | Engineering/Data | _TBD_ | Not started | Tie to analytics backlog |

**Pre-Read Packet Checklist**
- Current app usage dashboards (Firebase/Amplitude snapshots).
- Competitive landscape summary (top 5 apps, differentiators, pricing).
- AI capability overview (models, datasets, performance benchmarks, ethical considerations).
- Existing user interviews or survey highlights.
- Draft financial model and monetization experiments.

**Post-Workshop Follow-Up**
- Publish workshop notes and artifacts within 24 hours (owner: Product Lead).
- Assign action items with deadlines in the project tracker (owner: PMO/Product Ops).
- Schedule validation sessions for top risks (e.g., AI accuracy, data privacy) (owner: Data/AI & Compliance).
- Update overall product roadmap and share with leadership within one week (owner: Product Lead).
