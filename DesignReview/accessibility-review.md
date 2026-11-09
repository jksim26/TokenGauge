# Token Gauge accessibility review — 2026-10-28

Applied design:accessibility-review to the native SwiftUI implementation and rendered previews.

Verified: dark/light/accented previews generated for small, medium, large; numeric values convey usage without relying on colour; provider shapes have names; gauge accessibility descriptions include primary and Fable usage, reset timestamps, and elapsed-window percentage. Reset formatting assertions and six data tests passed. Corrected small-widget Fable-label spacing. Main percentages share a centre baseline. Removed the app icon's central needle/hub.

Remaining limitations: the tiny F label is visually small (4.5 pt in small size); the full name is available in the accessibility description. Track and coloured highlight contrast varies by wallpaper/material and is not certified to meet 3:1. Text uses adaptive primary colours, with a darker Fable text colour in light mode. Keyboard activation and actual VoiceOver announcements have not been exercised. Native widget background/refraction cannot be fully assessed from ImageRenderer snapshots. This is a partial accessibility review, not a WCAG conformance claim.

## Native proportions update

Medium rings increased from 62 to 70 pt; window labels from 7 to 10 pt; reset times from 8 to 10.5 pt with medium weight and 90% primary colour. Percentages use standard SF system font rather than rounded. Small rings increased to 48 pt and rows fit within the 132 pt content height. Larger labels preserve the 12:30–11:30 opening. Reset timestamps remain one line and may shrink by up to 15% for long localized strings. Dark/light/accented native previews inspected; usage and resets remain available through combined accessibility descriptions. Tiny F label remains a secondary visual cue, with full Fable name in accessibility text. Live VoiceOver and keyboard testing still unverified.

## Battery-reference refinement

Medium ring diameter 64 pt and bar width 6 pt; 300-degree open track from 1 to 11 o’clock, rounded endpoints. Reset spacing increased to 13 pt. Main usage follows the supplied Battery reference green with a subtle along-arc gradient; Fable uses pale mint and a separate inner track. Larger readable labels and reset times retained. Dark/light previews checked for clipping and text overlap; percentages and reset descriptions preserve non-colour access to values. Reduced the rendering to a continuous conic fill to avoid segmented edge artifacts. Native background appearance and actual VoiceOver interaction remain unverified.
