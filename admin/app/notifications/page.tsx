'use client';

import { FormEvent, useEffect, useState } from 'react';

import { useAdminAuth } from '../../components/admin-auth-provider';
import { DashboardShell } from '../../components/dashboard-shell';
import {
  Alert,
  Badge,
  Button,
  Card,
  Field,
  Input,
  Select,
  StatusBadge,
  Textarea,
} from '../../components/ui';
import { apiFetch } from '../../lib/api-client';
import { mutedTextStyle, splitList } from '../../lib/ui';

interface NotificationTemplateItem {
  id: string;
  name: string;
  title: { fr: string; en: string };
  body: { fr: string; en: string };
  channels: string[];
  isCritical: boolean;
}

interface NotificationCampaignItem {
  id: string;
  name: string;
  templateId: string | null;
  audienceType: string;
  channels: string[];
  scheduledFor: string | null;
  status: string;
  linkedCaseId: string | null;
}

interface NotificationDeliveryItem {
  id: string;
  recipientName: string;
  channel: string;
  status: string;
  deliveredAt: string | null;
}

export default function NotificationsPage() {
  const { session } = useAdminAuth();
  const [templates, setTemplates] = useState<NotificationTemplateItem[]>([]);
  const [campaigns, setCampaigns] = useState<NotificationCampaignItem[]>([]);
  const [deliveries, setDeliveries] = useState<NotificationDeliveryItem[]>([]);
  const [selectedCampaignId, setSelectedCampaignId] = useState<string | null>(
    null,
  );
  const [statusMessage, setStatusMessage] = useState<string | null>(null);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [templateForm, setTemplateForm] = useState({
    name: '',
    titleFr: '',
    titleEn: '',
    bodyFr: '',
    bodyEn: '',
    channels: 'push,in_app,email',
    isCritical: false,
  });
  const [campaignForm, setCampaignForm] = useState({
    name: '',
    templateId: '',
    audienceType: 'all_users',
    filtersJson: '{}',
    channels: 'push',
    scheduledFor: '',
    linkedCaseId: '',
  });

  async function loadNotifications() {
    setErrorMessage(null);
    try {
      const [templatesResponse, campaignsResponse] = await Promise.all([
        apiFetch<{ items: NotificationTemplateItem[] }>(
          '/admin/notifications/templates',
        ),
        apiFetch<{ items: NotificationCampaignItem[] }>(
          '/admin/notifications/campaigns',
        ),
      ]);

      setTemplates(templatesResponse.items);
      setCampaigns(campaignsResponse.items);
      const nextCampaignId =
        selectedCampaignId ?? campaignsResponse.items[0]?.id ?? null;
      setSelectedCampaignId(nextCampaignId);

      if (nextCampaignId) {
        const deliveriesResponse = await apiFetch<{
          items: NotificationDeliveryItem[];
        }>(`/admin/notifications/campaigns/${nextCampaignId}/deliveries`);
        setDeliveries(deliveriesResponse.items);
      } else {
        setDeliveries([]);
      }
    } catch (error) {
      setErrorMessage(
        error instanceof Error
          ? error.message
          : 'Unable to load notifications.',
      );
    }
  }

  useEffect(() => {
    if (!session) {
      return;
    }
    void loadNotifications();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [session]);

  useEffect(() => {
    if (!session) {
      return;
    }
    if (!selectedCampaignId) {
      setDeliveries([]);
      return;
    }

    // Guard against an out-of-order resolution overwriting deliveries with
    // stale data when the user switches campaigns quickly.
    let cancelled = false;
    void apiFetch<{ items: NotificationDeliveryItem[] }>(
      `/admin/notifications/campaigns/${selectedCampaignId}/deliveries`,
    )
      .then((response) => {
        if (!cancelled) setDeliveries(response.items);
      })
      .catch((error) => {
        if (!cancelled)
          setErrorMessage(
            error instanceof Error
              ? error.message
              : 'Unable to load deliveries.',
          );
      });
    return () => {
      cancelled = true;
    };
  }, [selectedCampaignId, session]);

  async function submitTemplate(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setStatusMessage(null);
    setErrorMessage(null);

    try {
      await apiFetch('/admin/notifications/templates', {
        method: 'POST',
        body: {
          name: templateForm.name,
          title: { fr: templateForm.titleFr, en: templateForm.titleEn },
          body: { fr: templateForm.bodyFr, en: templateForm.bodyEn },
          channels: splitList(templateForm.channels),
          isCritical: templateForm.isCritical,
        },
      });
      setTemplateForm({
        name: '',
        titleFr: '',
        titleEn: '',
        bodyFr: '',
        bodyEn: '',
        channels: 'push,in_app,email',
        isCritical: false,
      });
      setStatusMessage('Notification template created.');
      await loadNotifications();
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : 'Unable to create template.',
      );
    }
  }

  async function submitCampaign(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setStatusMessage(null);
    setErrorMessage(null);

    try {
      let parsedFilters: unknown;
      try {
        parsedFilters = JSON.parse(campaignForm.filtersJson);
      } catch {
        setErrorMessage('Filters JSON is invalid. Please enter valid JSON.');
        return;
      }
      await apiFetch('/admin/notifications/campaigns', {
        method: 'POST',
        body: {
          name: campaignForm.name,
          templateId: campaignForm.templateId || null,
          audienceType: campaignForm.audienceType,
          filters: parsedFilters,
          channels: splitList(campaignForm.channels),
          scheduledFor: campaignForm.scheduledFor
            ? new Date(campaignForm.scheduledFor).toISOString()
            : null,
          linkedCaseId: campaignForm.linkedCaseId || null,
        },
      });
      setCampaignForm({
        name: '',
        templateId: '',
        audienceType: 'all_users',
        filtersJson: '{}',
        channels: 'push',
        scheduledFor: '',
        linkedCaseId: '',
      });
      setStatusMessage('Notification campaign created.');
      await loadNotifications();
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : 'Unable to create campaign.',
      );
    }
  }

  return (
    <DashboardShell title="Notifications">
      <div style={{ display: 'grid', gap: 'var(--space-5)' }}>
        {statusMessage ? <Alert variant="success">{statusMessage}</Alert> : null}
        {errorMessage ? <Alert variant="danger">{errorMessage}</Alert> : null}

        <div
          style={{
            display: 'grid',
            gap: 'var(--space-5)',
            gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))',
          }}
        >
          <Card style={{ display: 'grid', gap: 'var(--space-3)' }}>
            <div>
              <h3 style={{ marginTop: 0 }}>Templates</h3>
              <p style={mutedTextStyle}>
                Create reusable push, in-app, or email templates for group or
                case-specific communication.
              </p>
            </div>
            <form onSubmit={submitTemplate} style={{ display: 'grid', gap: 'var(--space-3)' }}>
              <Field label="Template name">
                {({ id }) => (
                  <Input
                    id={id}
                    value={templateForm.name}
                    onChange={(event) =>
                      setTemplateForm((current) => ({
                        ...current,
                        name: event.target.value,
                      }))
                    }
                  />
                )}
              </Field>
              <Field label="Title (FR)">
                {({ id }) => (
                  <Input
                    id={id}
                    value={templateForm.titleFr}
                    onChange={(event) =>
                      setTemplateForm((current) => ({
                        ...current,
                        titleFr: event.target.value,
                      }))
                    }
                  />
                )}
              </Field>
              <Field label="Title (EN)">
                {({ id }) => (
                  <Input
                    id={id}
                    value={templateForm.titleEn}
                    onChange={(event) =>
                      setTemplateForm((current) => ({
                        ...current,
                        titleEn: event.target.value,
                      }))
                    }
                  />
                )}
              </Field>
              <Field label="Body (FR)">
                {({ id }) => (
                  <Textarea
                    id={id}
                    value={templateForm.bodyFr}
                    onChange={(event) =>
                      setTemplateForm((current) => ({
                        ...current,
                        bodyFr: event.target.value,
                      }))
                    }
                  />
                )}
              </Field>
              <Field label="Body (EN)">
                {({ id }) => (
                  <Textarea
                    id={id}
                    value={templateForm.bodyEn}
                    onChange={(event) =>
                      setTemplateForm((current) => ({
                        ...current,
                        bodyEn: event.target.value,
                      }))
                    }
                  />
                )}
              </Field>
              <Field label="Channels (comma-separated)">
                {({ id }) => (
                  <Input
                    id={id}
                    value={templateForm.channels}
                    onChange={(event) =>
                      setTemplateForm((current) => ({
                        ...current,
                        channels: event.target.value,
                      }))
                    }
                  />
                )}
              </Field>
              <label style={{ display: 'flex', gap: 'var(--space-2)', alignItems: 'center', fontWeight: 600 }}>
                <input
                  type="checkbox"
                  checked={templateForm.isCritical}
                  onChange={(event) =>
                    setTemplateForm((current) => ({
                      ...current,
                      isCritical: event.target.checked,
                    }))
                  }
                />
                Critical template
              </label>
              <Button type="submit">Add template</Button>
            </form>
            <div style={{ display: 'grid', gap: 'var(--space-3)' }}>
              {templates.map((template) => (
                <div
                  key={template.id}
                  style={{
                    borderTop: '1px solid var(--border)',
                    paddingTop: 'var(--space-3)',
                    display: 'grid',
                    gap: 'var(--space-2)',
                  }}
                >
                  <strong>{template.name}</strong>
                  <span style={mutedTextStyle}>{template.channels.join(', ')}</span>
                  <span>
                    <Badge variant={template.isCritical ? 'danger' : 'neutral'}>
                      {template.isCritical ? 'critical' : 'standard'}
                    </Badge>
                  </span>
                </div>
              ))}
            </div>
          </Card>

          <Card style={{ display: 'grid', gap: 'var(--space-3)' }}>
            <div>
              <h3 style={{ marginTop: 0 }}>Campaigns</h3>
              <p style={mutedTextStyle}>
                Launch a grouped reminder, a segmented push, or a case-specific
                update directly from operations.
              </p>
            </div>
            <form onSubmit={submitCampaign} style={{ display: 'grid', gap: 'var(--space-3)' }}>
              <Field label="Campaign name">
                {({ id }) => (
                  <Input
                    id={id}
                    value={campaignForm.name}
                    onChange={(event) =>
                      setCampaignForm((current) => ({
                        ...current,
                        name: event.target.value,
                      }))
                    }
                  />
                )}
              </Field>
              <Field label="Template">
                {({ id }) => (
                  <Select
                    id={id}
                    value={campaignForm.templateId}
                    onChange={(event) =>
                      setCampaignForm((current) => ({
                        ...current,
                        templateId: event.target.value,
                      }))
                    }
                  >
                    <option value="">No template</option>
                    {templates.map((template) => (
                      <option key={template.id} value={template.id}>
                        {template.name}
                      </option>
                    ))}
                  </Select>
                )}
              </Field>
              <Field label="Audience type">
                {({ id }) => (
                  <Input
                    id={id}
                    value={campaignForm.audienceType}
                    onChange={(event) =>
                      setCampaignForm((current) => ({
                        ...current,
                        audienceType: event.target.value,
                      }))
                    }
                    placeholder="all_users / by_case_status / by_role / specific_users"
                  />
                )}
              </Field>
              <Field label="Channels (comma-separated)">
                {({ id }) => (
                  <Input
                    id={id}
                    value={campaignForm.channels}
                    onChange={(event) =>
                      setCampaignForm((current) => ({
                        ...current,
                        channels: event.target.value,
                      }))
                    }
                  />
                )}
              </Field>
              <Field label="Filters JSON">
                {({ id }) => (
                  <Textarea
                    id={id}
                    value={campaignForm.filtersJson}
                    onChange={(event) =>
                      setCampaignForm((current) => ({
                        ...current,
                        filtersJson: event.target.value,
                      }))
                    }
                  />
                )}
              </Field>
              <Field label="Scheduled for">
                {({ id }) => (
                  <Input
                    id={id}
                    type="datetime-local"
                    value={campaignForm.scheduledFor}
                    onChange={(event) =>
                      setCampaignForm((current) => ({
                        ...current,
                        scheduledFor: event.target.value,
                      }))
                    }
                  />
                )}
              </Field>
              <Field label="Linked case ID">
                {({ id }) => (
                  <Input
                    id={id}
                    value={campaignForm.linkedCaseId}
                    onChange={(event) =>
                      setCampaignForm((current) => ({
                        ...current,
                        linkedCaseId: event.target.value,
                      }))
                    }
                  />
                )}
              </Field>
              <Button type="submit">Launch campaign</Button>
            </form>
            <div style={{ display: 'grid', gap: 'var(--space-2)' }}>
              {campaigns.map((campaign) => (
                <button
                  key={campaign.id}
                  type="button"
                  onClick={() => setSelectedCampaignId(campaign.id)}
                  aria-pressed={selectedCampaignId === campaign.id}
                  style={{
                    textAlign: 'left',
                    border:
                      selectedCampaignId === campaign.id
                        ? '2px solid var(--brand)'
                        : '1px solid var(--border)',
                    borderRadius: 'var(--radius-md)',
                    padding: 'var(--space-3)',
                    background: 'var(--surface)',
                    cursor: 'pointer',
                    display: 'grid',
                    gap: 'var(--space-2)',
                  }}
                >
                  <strong>{campaign.name}</strong>
                  <span style={mutedTextStyle}>
                    {campaign.audienceType} • {campaign.channels.join(', ')}
                  </span>
                  <span>
                    <StatusBadge status={campaign.status} />
                  </span>
                </button>
              ))}
            </div>
          </Card>
        </div>

        <Card>
          <h3 style={{ marginTop: 0 }}>Recent deliveries</h3>
          <p style={mutedTextStyle}>Delivery tracking for the selected campaign.</p>
          <div style={{ display: 'grid', gap: 'var(--space-3)' }}>
            {deliveries.map((delivery) => (
              <div
                key={delivery.id}
                style={{
                  borderTop: '1px solid var(--border)',
                  paddingTop: 'var(--space-3)',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  gap: 12,
                  flexWrap: 'wrap',
                }}
              >
                <span>
                  <strong>{delivery.recipientName}</strong>
                  <span style={{ ...mutedTextStyle, marginLeft: 8 }}>
                    {delivery.channel}
                    {delivery.deliveredAt ? ` • ${delivery.deliveredAt}` : ''}
                  </span>
                </span>
                <StatusBadge status={delivery.status} />
              </div>
            ))}
          </div>
        </Card>
      </div>
    </DashboardShell>
  );
}
