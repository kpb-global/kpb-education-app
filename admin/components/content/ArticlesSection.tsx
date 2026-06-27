'use client';

import { FormEvent, useEffect, useState } from 'react';

import { apiFetch } from '../../lib/api-client';
import { mutedTextStyle, splitList } from '../../lib/ui';
import { useAdminAuth } from '../admin-auth-provider';
import {
  Alert,
  Button,
  Field,
  Input,
  Select,
  StatusBadge,
  Textarea,
} from '../ui';
import { CrudSection } from './CrudSection';

interface ArticleItem {
  id: string;
  slug?: string;
  title: { fr: string; en: string };
  category: string;
  authorName: string;
  status: string;
  summary?: { fr: string; en: string };
  content?: { fr: string; en: string };
  tags?: string[];
}

const EMPTY_FORM = {
  slug: '',
  category: 'guides',
  titleFr: '',
  titleEn: '',
  summaryFr: '',
  summaryEn: '',
  contentFr: '',
  contentEn: '',
  tags: '',
  authorName: 'KPB Editorial',
  status: 'draft',
};

const full = { gridColumn: '1 / -1' } as const;

export function ArticlesSection() {
  const { session } = useAdminAuth();
  const [items, setItems] = useState<ArticleItem[]>([]);
  const [form, setForm] = useState(EMPTY_FORM);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [statusMessage, setStatusMessage] = useState<string | null>(null);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  async function load() {
    setErrorMessage(null);
    try {
      const response = await apiFetch<{ items: ArticleItem[] }>('/admin/articles');
      setItems(response.items);
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : 'Unable to load articles.',
      );
    }
  }

  useEffect(() => {
    if (!session) return;
    void load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [session]);

  function resetForm() {
    setForm(EMPTY_FORM);
    setEditingId(null);
  }

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setStatusMessage(null);
    setErrorMessage(null);

    const body = {
      slug: form.slug,
      category: form.category,
      title: { fr: form.titleFr, en: form.titleEn },
      summary: { fr: form.summaryFr, en: form.summaryEn },
      content: { fr: form.contentFr, en: form.contentEn },
      tags: splitList(form.tags),
      authorName: form.authorName,
      status: form.status,
      publishedAt: form.status === 'published' ? new Date().toISOString() : null,
    };

    try {
      if (editingId) {
        await apiFetch(`/admin/articles/${editingId}`, { method: 'PATCH', body });
        setStatusMessage('Article updated successfully.');
      } else {
        await apiFetch('/admin/articles', { method: 'POST', body });
        setStatusMessage('Article added to the editorial queue.');
      }
      resetForm();
      await load();
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : 'Unable to create article.',
      );
    }
  }

  function startEdit(article: ArticleItem) {
    setEditingId(article.id);
    setForm({
      slug: article.slug ?? '',
      category: article.category,
      titleFr: article.title.fr,
      titleEn: article.title.en,
      summaryFr: article.summary?.fr ?? '',
      summaryEn: article.summary?.en ?? '',
      contentFr: article.content?.fr ?? '',
      contentEn: article.content?.en ?? '',
      tags: article.tags?.join(',') ?? '',
      authorName: article.authorName,
      status: article.status,
    });
  }

  const form_ = (
    <form
      onSubmit={submit}
      style={{ display: 'grid', gap: 'var(--space-3)', gridTemplateColumns: '1fr 1fr' }}
    >
      <Field label="Slug">
        {({ id }) => (
          <Input id={id} value={form.slug} onChange={(e) => setForm((c) => ({ ...c, slug: e.target.value }))} />
        )}
      </Field>
      <Field label="Category">
        {({ id }) => (
          <Input id={id} value={form.category} onChange={(e) => setForm((c) => ({ ...c, category: e.target.value }))} />
        )}
      </Field>
      <Field label="Title (FR)">
        {({ id }) => (
          <Input id={id} value={form.titleFr} onChange={(e) => setForm((c) => ({ ...c, titleFr: e.target.value }))} />
        )}
      </Field>
      <Field label="Title (EN)">
        {({ id }) => (
          <Input id={id} value={form.titleEn} onChange={(e) => setForm((c) => ({ ...c, titleEn: e.target.value }))} />
        )}
      </Field>
      <div style={full}>
        <Field label="Summary (FR)">
          {({ id }) => (
            <Textarea id={id} value={form.summaryFr} onChange={(e) => setForm((c) => ({ ...c, summaryFr: e.target.value }))} />
          )}
        </Field>
      </div>
      <div style={full}>
        <Field label="Summary (EN)">
          {({ id }) => (
            <Textarea id={id} value={form.summaryEn} onChange={(e) => setForm((c) => ({ ...c, summaryEn: e.target.value }))} />
          )}
        </Field>
      </div>
      <div style={full}>
        <Field label="Content (FR)">
          {({ id }) => (
            <Textarea id={id} value={form.contentFr} onChange={(e) => setForm((c) => ({ ...c, contentFr: e.target.value }))} />
          )}
        </Field>
      </div>
      <div style={full}>
        <Field label="Content (EN)">
          {({ id }) => (
            <Textarea id={id} value={form.contentEn} onChange={(e) => setForm((c) => ({ ...c, contentEn: e.target.value }))} />
          )}
        </Field>
      </div>
      <Field label="Tags (comma-separated)">
        {({ id }) => (
          <Input id={id} value={form.tags} placeholder="scholarships,canada,bachelor" onChange={(e) => setForm((c) => ({ ...c, tags: e.target.value }))} />
        )}
      </Field>
      <Field label="Author">
        {({ id }) => (
          <Input id={id} value={form.authorName} onChange={(e) => setForm((c) => ({ ...c, authorName: e.target.value }))} />
        )}
      </Field>
      <Field label="Status">
        {({ id }) => (
          <Select id={id} value={form.status} onChange={(e) => setForm((c) => ({ ...c, status: e.target.value }))}>
            <option value="draft">Draft</option>
            <option value="published">Published</option>
            <option value="archived">Archived</option>
          </Select>
        )}
      </Field>
      <div style={{ ...full, display: 'flex', gap: 'var(--space-2)', flexWrap: 'wrap' }}>
        <Button type="submit">{editingId ? 'Update article' : 'Add article'}</Button>
        {editingId ? (
          <Button type="button" variant="secondary" onClick={resetForm}>
            Cancel
          </Button>
        ) : null}
      </div>
    </form>
  );

  return (
    <div style={{ display: 'grid', gap: 'var(--space-4)' }}>
      {statusMessage ? <Alert variant="success">{statusMessage}</Alert> : null}
      {errorMessage ? <Alert variant="danger">{errorMessage}</Alert> : null}
      <CrudSection
        title="Editorial content"
        description="Publish guidance articles that can surface on home, scholarships, and community entry points."
        form={form_}
        items={items}
        getKey={(article) => article.id}
        editingId={editingId}
        onSelect={startEdit}
        emptyLabel="No articles yet."
        renderItem={(article) => (
          <>
            <strong>{article.title.fr}</strong>
            <span style={{ ...mutedTextStyle, fontSize: 'var(--text-sm)' }}>
              {article.category} • {article.authorName}
            </span>
            <span>
              <StatusBadge status={article.status} />
            </span>
          </>
        )}
      />
    </div>
  );
}
