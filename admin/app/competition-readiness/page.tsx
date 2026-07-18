import { Suspense } from 'react';

import { CompetitionReadinessHub } from '../../components/competition-readiness/readiness-hub';

export default function CompetitionReadinessPage() {
  return (
    <Suspense fallback={<div aria-busy="true">Chargement…</div>}>
      <CompetitionReadinessHub />
    </Suspense>
  );
}
