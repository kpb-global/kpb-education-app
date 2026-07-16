'use client';
/* eslint-disable @next/next/no-img-element -- YouTube thumbnails are remote admin previews. */

import { CSSProperties, useEffect, useMemo, useState } from 'react';

import { apiFetch } from '../../lib/api-client';
import { useLocale } from '../locale-provider';
import { Alert, Button, Field, Input, Select, Textarea } from '../ui';
import type {
  ScholarshipEntry,
  ScholarshipVideoEntry,
  ScholarshipVideoStatus,
} from './types';

interface VideoDraft {
  url: string;
  titleFr: string;
  titleEn: string;
  descriptionFr: string;
  descriptionEn: string;
  languageCode: string;
  status: ScholarshipVideoStatus;
  displayOrder: string;
  isFeatured: boolean;
}

const EMPTY_VIDEO: VideoDraft = {
  url: '',
  titleFr: '',
  titleEn: '',
  descriptionFr: '',
  descriptionEn: '',
  languageCode: 'fr',
  status: 'published',
  displayOrder: '0',
  isFeatured: false,
};

function youtubeId(value: string): string | null {
  const raw = value.trim();
  if (/^[A-Za-z0-9_-]{11}$/.test(raw)) return raw;
  try {
    const url = new URL(raw);
    if (url.hostname === 'youtu.be') {
      const id = url.pathname.split('/').filter(Boolean)[0] ?? '';
      return /^[A-Za-z0-9_-]{11}$/.test(id) ? id : null;
    }
    const queryId = url.searchParams.get('v') ?? '';
    if (/^[A-Za-z0-9_-]{11}$/.test(queryId)) return queryId;
    const segments = url.pathname.split('/').filter(Boolean);
    const marker = segments.findIndex((part) =>
      ['embed', 'shorts', 'live'].includes(part),
    );
    const pathId = marker >= 0 ? (segments[marker + 1] ?? '') : '';
    return /^[A-Za-z0-9_-]{11}$/.test(pathId) ? pathId : null;
  } catch {
    return null;
  }
}

export function ScholarshipVideosEditor({
  entry,
  onChanged,
}: {
  entry: ScholarshipEntry;
  onChanged: (videos: ScholarshipVideoEntry[]) => void;
}) {
  const { t } = useLocale();
  const [videos, setVideos] = useState<ScholarshipVideoEntry[]>(entry.videos ?? []);
  const [draft, setDraft] = useState<VideoDraft>(EMPTY_VIDEO);
  const [pending, setPending] = useState(false);
  const [unavailable, setUnavailable] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const parsedId = useMemo(() => youtubeId(draft.url), [draft.url]);

  useEffect(() => {
    setVideos(entry.videos ?? []);
    setDraft(EMPTY_VIDEO);
    setUnavailable(false);
    setError(null);
  }, [entry]);

  function patch(next: Partial<VideoDraft>) {
    setDraft((current) => ({ ...current, ...next }));
  }

  async function addVideo() {
    if (!parsedId || !draft.titleFr.trim()) {
      setError(t('scholarships.videoValidationError'));
      return;
    }
    setPending(true);
    setError(null);
    setUnavailable(false);
    try {
      const created = await apiFetch<ScholarshipVideoEntry>(
        `/admin/catalog/scholarships/${entry.id}/videos`,
        {
          method: 'POST',
          body: {
            // The backend accepts a canonical HTTPS URL and extracts the
            // immutable 11-character YouTube id server-side.
            youtubeUrl: `https://www.youtube.com/watch?v=${parsedId}`,
            titleFr: draft.titleFr.trim(),
            titleEn: draft.titleEn.trim() || draft.titleFr.trim(),
            descriptionFr: draft.descriptionFr.trim(),
            descriptionEn: draft.descriptionEn.trim(),
            languageCode: draft.languageCode.trim() || 'fr',
            status: draft.status,
            displayOrder: Number(draft.displayOrder) || 0,
            isFeatured: draft.isFeatured,
          },
        },
      );
      const current = created.isFeatured
        ? videos.map((video) => ({ ...video, isFeatured: false }))
        : videos;
      const next = [...current, created].sort(
        (a, b) => (a.displayOrder ?? 0) - (b.displayOrder ?? 0),
      );
      setVideos(next);
      onChanged(next);
      setDraft(EMPTY_VIDEO);
    } catch (exception) {
      const status = (exception as Error & { status?: number }).status;
      if (status === 404 || status === 405 || status === 501) {
        setUnavailable(true);
      } else {
        setError(
          exception instanceof Error
            ? exception.message
            : t('scholarships.videoSaveError'),
        );
      }
    } finally {
      setPending(false);
    }
  }

  async function updateVideoStatus(
    video: ScholarshipVideoEntry,
    status: ScholarshipVideoStatus,
  ) {
    if (video.status === status) return;
    setPending(true);
    setError(null);
    setUnavailable(false);
    try {
      const updated = await apiFetch<ScholarshipVideoEntry>(
        `/admin/catalog/scholarships/${entry.id}/videos/${video.id}`,
        { method: 'PATCH', body: { status } },
      );
      const next = videos.map((item) =>
        item.id === video.id ? updated : item,
      );
      setVideos(next);
      onChanged(next);
    } catch (exception) {
      const httpStatus = (exception as Error & { status?: number }).status;
      if (httpStatus === 404 || httpStatus === 405 || httpStatus === 501) {
        setUnavailable(true);
      } else {
        setError(
          exception instanceof Error
            ? exception.message
            : t('scholarships.videoSaveError'),
        );
      }
    } finally {
      setPending(false);
    }
  }

  async function removeVideo(video: ScholarshipVideoEntry) {
    setPending(true);
    setError(null);
    try {
      await apiFetch(
        `/admin/catalog/scholarships/${entry.id}/videos/${video.id}`,
        { method: 'DELETE' },
      );
      const next = videos.filter((item) => item.id !== video.id);
      setVideos(next);
      onChanged(next);
    } catch (exception) {
      const status = (exception as Error & { status?: number }).status;
      if (status === 404 || status === 405 || status === 501) {
        setUnavailable(true);
      } else {
        setError(
          exception instanceof Error
            ? exception.message
            : t('scholarships.videoSaveError'),
        );
      }
    } finally {
      setPending(false);
    }
  }

  return (
    <section style={{ display: 'grid', gap: 12 }}>
      <div>
        <h4 style={{ margin: 0 }}>{t('scholarships.videosTitle')}</h4>
        <p style={{ margin: '4px 0 0', color: 'var(--text-muted)', fontSize: 'var(--text-sm)' }}>
          {t('scholarships.videosHint')}
        </p>
      </div>
      {unavailable ? (
        <Alert variant="warning">{t('scholarships.videoApiUnavailable')}</Alert>
      ) : null}
      {error ? <Alert variant="danger">{error}</Alert> : null}

      {videos.map((video) => (
        <div key={video.id} style={videoRowStyle}>
          <img
            src={video.thumbnailUrl || `https://img.youtube.com/vi/${video.youtubeVideoId}/mqdefault.jpg`}
            alt=""
            width={112}
            height={63}
            loading="lazy"
            style={{ objectFit: 'cover', borderRadius: 8 }}
          />
          <div style={{ flex: 1, minWidth: 0 }}>
            <strong>{video.titleFr || video.titleEn || video.youtubeVideoId}</strong>
            <div style={{ color: 'var(--text-muted)', fontSize: 'var(--text-xs)' }}>
              {video.languageCode?.toUpperCase() || 'FR'} · #{video.displayOrder ?? 0}
            </div>
          </div>
          <Select
            aria-label={t('scholarships.videoStatusLabel')}
            value={video.status ?? 'draft'}
            disabled={pending}
            onChange={(event) =>
              updateVideoStatus(
                video,
                event.target.value as ScholarshipVideoStatus,
              )
            }
            style={{ width: 120 }}
          >
            <option value="draft">{t('scholarships.videoStatusDraft')}</option>
            <option value="published">{t('scholarships.videoStatusPublished')}</option>
            <option value="archived">{t('scholarships.videoStatusArchived')}</option>
          </Select>
          <Button
            size="sm"
            variant="dangerOutline"
            disabled={pending}
            onClick={() => removeVideo(video)}
          >
            {t('scholarships.removeVideoCta')}
          </Button>
        </div>
      ))}

      <div style={{ display: 'grid', gap: 10, padding: 12, border: '1px solid var(--border)', borderRadius: 12 }}>
        <Field label={t('scholarships.youtubeUrlLabel')} error={draft.url && !parsedId ? t('scholarships.youtubeUrlInvalid') : undefined}>
          {({ id, invalid }) => (
            <Input
              id={id}
              invalid={invalid}
              type="url"
              value={draft.url}
              placeholder="https://www.youtube.com/watch?v=…"
              onChange={(event) => patch({ url: event.target.value })}
            />
          )}
        </Field>
        {parsedId ? (
          <iframe
            title={t('scholarships.videoPreviewTitle')}
            src={`https://www.youtube-nocookie.com/embed/${parsedId}`}
            loading="lazy"
            allow="accelerometer; autoplay; encrypted-media; gyroscope; picture-in-picture"
            allowFullScreen
            style={{ width: '100%', maxWidth: 480, aspectRatio: '16 / 9', border: 0, borderRadius: 12 }}
          />
        ) : null}
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 10 }}>
          <Field label={t('scholarships.videoTitleFrLabel')}>
            {({ id }) => <Input id={id} value={draft.titleFr} onChange={(event) => patch({ titleFr: event.target.value })} />}
          </Field>
          <Field label={t('scholarships.videoTitleEnLabel')}>
            {({ id }) => <Input id={id} value={draft.titleEn} onChange={(event) => patch({ titleEn: event.target.value })} />}
          </Field>
          <Field label={t('scholarships.videoLanguageLabel')}>
            {({ id }) => <Input id={id} value={draft.languageCode} onChange={(event) => patch({ languageCode: event.target.value })} />}
          </Field>
          <Field label={t('scholarships.videoStatusLabel')}>
            {({ id }) => (
              <Select
                id={id}
                value={draft.status}
                onChange={(event) =>
                  patch({ status: event.target.value as ScholarshipVideoStatus })
                }
              >
                <option value="published">{t('scholarships.videoStatusPublished')}</option>
                <option value="draft">{t('scholarships.videoStatusDraft')}</option>
                <option value="archived">{t('scholarships.videoStatusArchived')}</option>
              </Select>
            )}
          </Field>
          <Field label={t('scholarships.videoOrderLabel')}>
            {({ id }) => <Input id={id} type="number" value={draft.displayOrder} onChange={(event) => patch({ displayOrder: event.target.value })} />}
          </Field>
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
          <Field label={t('scholarships.videoDescriptionFrLabel')}>
            {({ id }) => <Textarea id={id} rows={3} value={draft.descriptionFr} onChange={(event) => patch({ descriptionFr: event.target.value })} />}
          </Field>
          <Field label={t('scholarships.videoDescriptionEnLabel')}>
            {({ id }) => <Textarea id={id} rows={3} value={draft.descriptionEn} onChange={(event) => patch({ descriptionEn: event.target.value })} />}
          </Field>
        </div>
        <label style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <input type="checkbox" checked={draft.isFeatured} onChange={(event) => patch({ isFeatured: event.target.checked })} />
          {t('scholarships.videoFeaturedLabel')}
        </label>
        <div>
          <Button onClick={addVideo} loading={pending}>
            {t('scholarships.addVideoCta')}
          </Button>
        </div>
      </div>
    </section>
  );
}

const videoRowStyle: CSSProperties = {
  display: 'flex',
  alignItems: 'center',
  gap: 12,
  padding: 10,
  border: '1px solid var(--border-soft)',
  borderRadius: 12,
  background: 'var(--bg)',
};
