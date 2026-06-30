'use client';

import { FormEvent, useEffect, useState } from 'react';

import { useAdminAuth } from '../../components/admin-auth-provider';
import { DashboardShell } from '../../components/dashboard-shell';
import { apiFetch } from '../../lib/api-client';
import {
  badgeStyle,
  buttonStyle,
  inputStyle,
  labelStyle,
  mutedTextStyle,
  panelStyle,
  textareaStyle,
} from '../../lib/ui';

interface ForumCategoryItem {
  id: string;
  label: { fr: string; en: string };
  description: { fr: string; en: string };
  displayOrder: number;
  status: string;
}

interface ForumTagItem {
  id: string;
  label: { fr: string; en: string };
  description: { fr: string; en: string };
  displayOrder: number;
  status: string;
}

interface ModerationItem {
  id: string;
  subject: string;
  targetType: string;
  reportsCount: number;
  suggestedAction: string;
}

export default function CommunityPage() {
  const { session } = useAdminAuth();
  const [forumCategories, setForumCategories] = useState<ForumCategoryItem[]>(
    [],
  );
  const [forumTags, setForumTags] = useState<ForumTagItem[]>([]);
  const [moderationQueue, setModerationQueue] = useState<ModerationItem[]>([]);
  const [statusMessage, setStatusMessage] = useState<string | null>(null);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [categoryForm, setCategoryForm] = useState({
    labelFr: '',
    labelEn: '',
    descriptionFr: '',
    descriptionEn: '',
    displayOrder: '1',
    status: 'draft',
  });
  const [tagForm, setTagForm] = useState({
    labelFr: '',
    labelEn: '',
    descriptionFr: '',
    descriptionEn: '',
    displayOrder: '1',
    status: 'draft',
  });
  const [editingCategoryId, setEditingCategoryId] = useState<string | null>(null);
  const [editingTagId, setEditingTagId] = useState<string | null>(null);

  async function loadCommunity() {
    setErrorMessage(null);
    try {
      const [categoriesResponse, tagsResponse, moderationResponse] =
        await Promise.all([
          apiFetch<{ items: ForumCategoryItem[] }>('/admin/forum-categories'),
          apiFetch<{ items: ForumTagItem[] }>('/admin/forum-tags'),
          apiFetch<{ items: ModerationItem[] }>('/admin/forum-moderation'),
        ]);
      setForumCategories(categoriesResponse.items);
      setForumTags(tagsResponse.items);
      setModerationQueue(moderationResponse.items);
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : 'Unable to load community.',
      );
    }
  }

  useEffect(() => {
    if (!session) {
      return;
    }
    void loadCommunity();
  }, [session]);

  async function submitCategory(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setStatusMessage(null);
    setErrorMessage(null);

    try {
      if (editingCategoryId) {
        await apiFetch(`/admin/forum-categories/${editingCategoryId}`, {
          method: 'PATCH',
          body: {
            label: { fr: categoryForm.labelFr, en: categoryForm.labelEn },
            description: {
              fr: categoryForm.descriptionFr,
              en: categoryForm.descriptionEn,
            },
            displayOrder: Number(categoryForm.displayOrder),
            status: categoryForm.status,
          },
        });
        setStatusMessage('Forum category updated successfully.');
      } else {
        await apiFetch('/admin/forum-categories', {
          method: 'POST',
          body: {
            label: { fr: categoryForm.labelFr, en: categoryForm.labelEn },
            description: {
              fr: categoryForm.descriptionFr,
              en: categoryForm.descriptionEn,
            },
            displayOrder: Number(categoryForm.displayOrder),
            status: categoryForm.status,
          },
        });
        setStatusMessage('Forum category created successfully.');
      }

      setCategoryForm({
        labelFr: '',
        labelEn: '',
        descriptionFr: '',
        descriptionEn: '',
        displayOrder: '1',
        status: 'draft',
      });
      setEditingCategoryId(null);
      await loadCommunity();
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : 'Unable to create category.',
      );
    }
  }

  async function submitTag(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setStatusMessage(null);
    setErrorMessage(null);

    try {
      if (editingTagId) {
        await apiFetch(`/admin/forum-tags/${editingTagId}`, {
          method: 'PATCH',
          body: {
            label: { fr: tagForm.labelFr, en: tagForm.labelEn },
            description: { fr: tagForm.descriptionFr, en: tagForm.descriptionEn },
            displayOrder: Number(tagForm.displayOrder),
            status: tagForm.status,
          },
        });
        setStatusMessage('Forum topic tag updated successfully.');
      } else {
        await apiFetch('/admin/forum-tags', {
          method: 'POST',
          body: {
            label: { fr: tagForm.labelFr, en: tagForm.labelEn },
            description: { fr: tagForm.descriptionFr, en: tagForm.descriptionEn },
            displayOrder: Number(tagForm.displayOrder),
            status: tagForm.status,
          },
        });
        setStatusMessage('Forum topic tag created successfully.');
      }

      setTagForm({
        labelFr: '',
        labelEn: '',
        descriptionFr: '',
        descriptionEn: '',
        displayOrder: '1',
        status: 'draft',
      });
      setEditingTagId(null);
      await loadCommunity();
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : 'Unable to create tag.',
      );
    }
  }

  return (
    <DashboardShell title="Community">
      <div style={{ display: 'grid', gap: 18 }}>
        {statusMessage ? (
          <div style={{ ...panelStyle, background: '#ECFDF5', color: '#166534' }}>
            {statusMessage}
          </div>
        ) : null}
        {errorMessage ? (
          <div style={{ ...panelStyle, background: '#FEF2F2', color: '#B91C1C' }}>
            {errorMessage}
          </div>
        ) : null}

        <div style={{ display: 'grid', gap: 18, gridTemplateColumns: '1fr 1fr' }}>
          <section style={{ ...panelStyle, display: 'grid', gap: 14 }}>
            <div>
              <h3 style={{ marginTop: 0 }}>Forum categories</h3>
              <p style={mutedTextStyle}>
                Structure the student community by adding visible topic families.
              </p>
            </div>
            <form onSubmit={submitCategory} style={{ display: 'grid', gap: 12 }}>
              <label style={labelStyle}>
                Label (FR)
                <input
                  value={categoryForm.labelFr}
                  onChange={(event) =>
                    setCategoryForm((current) => ({
                      ...current,
                      labelFr: event.target.value,
                    }))
                  }
                  style={inputStyle}
                />
              </label>
              <label style={labelStyle}>
                Label (EN)
                <input
                  value={categoryForm.labelEn}
                  onChange={(event) =>
                    setCategoryForm((current) => ({
                      ...current,
                      labelEn: event.target.value,
                    }))
                  }
                  style={inputStyle}
                />
              </label>
              <label style={labelStyle}>
                Description (FR)
                <textarea
                  value={categoryForm.descriptionFr}
                  onChange={(event) =>
                    setCategoryForm((current) => ({
                      ...current,
                      descriptionFr: event.target.value,
                    }))
                  }
                  style={textareaStyle}
                />
              </label>
              <label style={labelStyle}>
                Description (EN)
                <textarea
                  value={categoryForm.descriptionEn}
                  onChange={(event) =>
                    setCategoryForm((current) => ({
                      ...current,
                      descriptionEn: event.target.value,
                    }))
                  }
                  style={textareaStyle}
                />
              </label>
              <div style={{ display: 'grid', gap: 12, gridTemplateColumns: '1fr 1fr' }}>
                <label style={labelStyle}>
                  Display order
                  <input
                    value={categoryForm.displayOrder}
                    onChange={(event) =>
                      setCategoryForm((current) => ({
                        ...current,
                        displayOrder: event.target.value,
                      }))
                    }
                    style={inputStyle}
                  />
                </label>
                <label style={labelStyle}>
                  Status
                  <select
                    value={categoryForm.status}
                    onChange={(event) =>
                      setCategoryForm((current) => ({
                        ...current,
                        status: event.target.value,
                      }))
                    }
                    style={inputStyle}
                  >
                    <option value="draft">Draft</option>
                    <option value="published">Published</option>
                    <option value="archived">Archived</option>
                  </select>
                </label>
              </div>
              <button type="submit" style={buttonStyle}>
                {editingCategoryId ? 'Update category' : 'Add category'}
              </button>
              {editingCategoryId && (
                <button
                  type="button"
                  onClick={() => {
                    setEditingCategoryId(null);
                    setCategoryForm({
                      labelFr: '',
                      labelEn: '',
                      descriptionFr: '',
                      descriptionEn: '',
                      displayOrder: '1',
                      status: 'draft',
                    });
                  }}
                  style={{ ...buttonStyle, background: '#64748b' }}
                >
                  Cancel
                </button>
              )}
            </form>
            <div style={{ display: 'grid', gap: 12 }}>
              {forumCategories.map((category) => (
                <div 
                  key={category.id} 
                  onClick={() => {
                    setEditingCategoryId(category.id);
                    setCategoryForm({
                      labelFr: category.label.fr,
                      labelEn: category.label.en,
                      descriptionFr: category.description.fr,
                      descriptionEn: category.description.en,
                      displayOrder: String(category.displayOrder),
                      status: category.status,
                    });
                  }}
                  style={{ 
                    borderTop: '1px solid #E2E8F0', 
                    paddingTop: 12,
                    cursor: 'pointer',
                    background: editingCategoryId === category.id ? '#f1f5f9' : 'transparent',
                    padding: '12px 8px',
                    borderRadius: 8,
                  }}
                >
                  <strong>{category.label.fr}</strong>
                  <p style={{ margin: '6px 0' }}>{category.description.fr}</p>
                  <span style={badgeStyle}>
                    Order {category.displayOrder} • {category.status}
                  </span>
                </div>
              ))}
            </div>
          </section>

          <section style={{ ...panelStyle, display: 'grid', gap: 14 }}>
            <div>
              <h3 style={{ marginTop: 0 }}>Forum topic tags</h3>
              <p style={mutedTextStyle}>
                Add lightweight tags used to guide discussions and discovery.
              </p>
            </div>
            <form onSubmit={submitTag} style={{ display: 'grid', gap: 12 }}>
              <label style={labelStyle}>
                Label (FR)
                <input
                  value={tagForm.labelFr}
                  onChange={(event) =>
                    setTagForm((current) => ({
                      ...current,
                      labelFr: event.target.value,
                    }))
                  }
                  style={inputStyle}
                />
              </label>
              <label style={labelStyle}>
                Label (EN)
                <input
                  value={tagForm.labelEn}
                  onChange={(event) =>
                    setTagForm((current) => ({
                      ...current,
                      labelEn: event.target.value,
                    }))
                  }
                  style={inputStyle}
                />
              </label>
              <label style={labelStyle}>
                Description (FR)
                <textarea
                  value={tagForm.descriptionFr}
                  onChange={(event) =>
                    setTagForm((current) => ({
                      ...current,
                      descriptionFr: event.target.value,
                    }))
                  }
                  style={textareaStyle}
                />
              </label>
              <label style={labelStyle}>
                Description (EN)
                <textarea
                  value={tagForm.descriptionEn}
                  onChange={(event) =>
                    setTagForm((current) => ({
                      ...current,
                      descriptionEn: event.target.value,
                    }))
                  }
                  style={textareaStyle}
                />
              </label>
              <div style={{ display: 'grid', gap: 12, gridTemplateColumns: '1fr 1fr' }}>
                <label style={labelStyle}>
                  Display order
                  <input
                    value={tagForm.displayOrder}
                    onChange={(event) =>
                      setTagForm((current) => ({
                        ...current,
                        displayOrder: event.target.value,
                      }))
                    }
                    style={inputStyle}
                  />
                </label>
                <label style={labelStyle}>
                  Status
                  <select
                    value={tagForm.status}
                    onChange={(event) =>
                      setTagForm((current) => ({
                        ...current,
                        status: event.target.value,
                      }))
                    }
                    style={inputStyle}
                  >
                    <option value="draft">Draft</option>
                    <option value="published">Published</option>
                    <option value="archived">Archived</option>
                  </select>
                </label>
              </div>
              <button type="submit" style={buttonStyle}>
                {editingTagId ? 'Update topic tag' : 'Add topic tag'}
              </button>
              {editingTagId && (
                <button
                  type="button"
                  onClick={() => {
                    setEditingTagId(null);
                    setTagForm({
                      labelFr: '',
                      labelEn: '',
                      descriptionFr: '',
                      descriptionEn: '',
                      displayOrder: '1',
                      status: 'draft',
                    });
                  }}
                  style={{ ...buttonStyle, background: '#64748b' }}
                >
                  Cancel
                </button>
              )}
            </form>
            <div style={{ display: 'grid', gap: 12 }}>
              {forumTags.map((tag) => (
                <div 
                  key={tag.id} 
                  onClick={() => {
                    setEditingTagId(tag.id);
                    setTagForm({
                      labelFr: tag.label.fr,
                      labelEn: tag.label.en,
                      descriptionFr: tag.description.fr,
                      descriptionEn: tag.description.en,
                      displayOrder: String(tag.displayOrder),
                      status: tag.status,
                    });
                  }}
                  style={{ 
                    borderTop: '1px solid #E2E8F0', 
                    paddingTop: 12,
                    cursor: 'pointer',
                    background: editingTagId === tag.id ? '#f1f5f9' : 'transparent',
                    padding: '12px 8px',
                    borderRadius: 8,
                  }}
                >
                  <strong>{tag.label.fr}</strong>
                  <p style={{ margin: '6px 0' }}>{tag.description.fr}</p>
                  <span style={badgeStyle}>
                    Order {tag.displayOrder} • {tag.status}
                  </span>
                </div>
              ))}
            </div>
          </section>
        </div>

        <section style={panelStyle}>
          <h3 style={{ marginTop: 0 }}>Moderation queue</h3>
          <p style={mutedTextStyle}>
            Reported items remain visible here for moderator follow-up and
            escalation.
          </p>
          <div style={{ display: 'grid', gap: 12 }}>
            {moderationQueue.map((item) => (
              <div key={item.id} style={{ borderTop: '1px solid #E2E8F0', paddingTop: 12 }}>
                <strong>{item.subject}</strong>
                <p style={{ margin: '6px 0' }}>
                  {item.targetType} • {item.reportsCount} reports
                </p>
                <span style={badgeStyle}>{item.suggestedAction}</span>
              </div>
            ))}
          </div>
        </section>
      </div>
    </DashboardShell>
  );
}
