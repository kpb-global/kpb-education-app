'use client';

import { FormEvent, useEffect, useState } from 'react';

import { DashboardShell } from '../../components/dashboard-shell';
import { apiFetch } from '../../lib/api-client';
import {
  badgeStyle,
  buttonStyle,
  inputStyle,
  labelStyle,
  mutedTextStyle,
  panelStyle,
  splitList,
  textareaStyle,
} from '../../lib/ui';

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
    void loadNotifications();
  }, []);

  useEffect(() => {
    if (!selectedCampaignId) {
      setDeliveries([]);
      return;
    }

    void apiFetch<{ items: NotificationDeliveryItem[] }>(
      `/admin/notifications/campaigns/${selectedCampaignId}/deliveries`,
    )
      .then((response) => setDeliveries(response.items))
      .catch((error) =>
        setErrorMessage(
          error instanceof Error
            ? error.message
            : 'Unable to load deliveries.',
        ),
      );
  }, [selectedCampaignId]);

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
              <h3 style={{ marginTop: 0 }}>Templates</h3>
              <p style={mutedTextStyle}>
                Create reusable push, in-app, or email templates for group or
                case-specific communication.
              </p>
            </div>
            <form onSubmit={submitTemplate} style={{ display: 'grid', gap: 12 }}>
              <label style={labelStyle}>
                Template name
                <input
                  value={templateForm.name}
                  onChange={(event) =>
                    setTemplateForm((current) => ({
                      ...current,
                      name: event.target.value,
                    }))
                  }
                  style={inputStyle}
                />
              </label>
              <label style={labelStyle}>
                Title (FR)
                <input
                  value={templateForm.titleFr}
                  onChange={(event) =>
                    setTemplateForm((current) => ({
                      ...current,
                      titleFr: event.target.value,
                    }))
                  }
                  style={inputStyle}
                />
              </label>
              <label style={labelStyle}>
                Title (EN)
                <input
                  value={templateForm.titleEn}
                  onChange={(event) =>
                    setTemplateForm((current) => ({
                      ...current,
                      titleEn: event.target.value,
                    }))
                  }
                  style={inputStyle}
                />
              </label>
              <label style={labelStyle}>
                Body (FR)
                <textarea
                  value={templateForm.bodyFr}
                  onChange={(event) =>
                    setTemplateForm((current) => ({
                      ...current,
                      bodyFr: event.target.value,
                    }))
                  }
                  style={textareaStyle}
                />
              </label>
              <label style={labelStyle}>
                Body (EN)
                <textarea
                  value={templateForm.bodyEn}
                  onChange={(event) =>
                    setTemplateForm((current) => ({
                      ...current,
                      bodyEn: event.target.value,
                    }))
                  }
                  style={textareaStyle}
                />
              </label>
              <label style={labelStyle}>
                Channels
                <input
                  value={templateForm.channels}
                  onChange={(event) =>
                    setTemplateForm((current) => ({
                      ...current,
                      channels: event.target.value,
                    }))
                  }
                  style={inputStyle}
                />
              </label>
              <label style={{ ...labelStyle, alignContent: 'end' }}>
                <span>Critical template</span>
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
              </label>
              <button type="submit" style={buttonStyle}>
                Add template
              </button>
            </form>
            <div style={{ display: 'grid', gap: 12 }}>
              {templates.map((template) => (
                <div key={template.id} style={{ borderTop: '1px solid #E2E8F0', paddingTop: 12 }}>
                  <strong>{template.name}</strong>
                  <p style={{ margin: '6px 0' }}>{template.channels.join(', ')}</p>
                  <span style={badgeStyle}>
                    {template.isCritical ? 'critical' : 'standard'}
                  </span>
                </div>
              ))}
            </div>
          </section>

          <section style={{ ...panelStyle, display: 'grid', gap: 14 }}>
            <div>
              <h3 style={{ marginTop: 0 }}>Campaigns</h3>
              <p style={mutedTextStyle}>
                Launch a grouped reminder, a segmented push, or a case-specific
                update directly from operations.
              </p>
            </div>
            <form onSubmit={submitCampaign} style={{ display: 'grid', gap: 12 }}>
              <label style={labelStyle}>
                Campaign name
                <input
                  value={campaignForm.name}
                  onChange={(event) =>
                    setCampaignForm((current) => ({
                      ...current,
                      name: event.target.value,
                    }))
                  }
                  style={inputStyle}
                />
              </label>
              <label style={labelStyle}>
                Template
                <select
                  value={campaignForm.templateId}
                  onChange={(event) =>
                    setCampaignForm((current) => ({
                      ...current,
                      templateId: event.target.value,
                    }))
                  }
                  style={inputStyle}
                >
                  <option value="">No template</option>
                  {templates.map((template) => (
                    <option key={template.id} value={template.id}>
                      {template.name}
                    </option>
                  ))}
                </select>
              </label>
              <label style={labelStyle}>
                Audience type
                <input
                  value={campaignForm.audienceType}
                  onChange={(event) =>
                    setCampaignForm((current) => ({
                      ...current,
                      audienceType: event.target.value,
                    }))
                  }
                  placeholder="all_users / by_case_status / by_role / specific_users"
                  style={inputStyle}
                />
              </label>
              <label style={labelStyle}>
                Channels
                <input
                  value={campaignForm.channels}
                  onChange={(event) =>
                    setCampaignForm((current) => ({
                      ...current,
                      channels: event.target.value,
                    }))
                  }
                  style={inputStyle}
                />
              </label>
              <label style={labelStyle}>
                Filters JSON
                <textarea
                  value={campaignForm.filtersJson}
                  onChange={(event) =>
                    setCampaignForm((current) => ({
                      ...current,
                      filtersJson: event.target.value,
                    }))
                  }
                  style={textareaStyle}
                />
              </label>
              <label style={labelStyle}>
                Scheduled for
                <input
                  type="datetime-local"
                  value={campaignForm.scheduledFor}
                  onChange={(event) =>
                    setCampaignForm((current) => ({
                      ...current,
                      scheduledFor: event.target.value,
                    }))
                  }
                  style={inputStyle}
                />
              </label>
              <label style={labelStyle}>
                Linked case ID
                <input
                  value={campaignForm.linkedCaseId}
                  onChange={(event) =>
                    setCampaignForm((current) => ({
                      ...current,
                      linkedCaseId: event.target.value,
                    }))
                  }
                  style={inputStyle}
                />
              </label>
              <button type="submit" style={buttonStyle}>
                Launch campaign
              </button>
            </form>
            <div style={{ display: 'grid', gap: 12 }}>
              {campaigns.map((campaign) => (
                <button
                  key={campaign.id}
                  onClick={() => setSelectedCampaignId(campaign.id)}
                  style={{
                    textAlign: 'left',
                    border: '1px solid #E2E8F0',
                    borderRadius: 16,
                    padding: 14,
                    background:
                      selectedCampaignId === campaign.id ? '#EEF2FF' : '#fff',
                    cursor: 'pointer',
                  }}
                >
                  <strong>{campaign.name}</strong>
                  <p style={{ margin: '6px 0' }}>
                    {campaign.audienceType} • {campaign.channels.join(', ')}
                  </p>
                  <span style={badgeStyle}>{campaign.status}</span>
                </button>
              ))}
            </div>
          </section>
        </div>

        <section style={panelStyle}>
          <h3 style={{ marginTop: 0 }}>Recent deliveries</h3>
          <p style={mutedTextStyle}>
            Delivery tracking for the selected campaign.
          </p>
          <div style={{ display: 'grid', gap: 12 }}>
            {deliveries.map((delivery) => (
              <div key={delivery.id} style={{ borderTop: '1px solid #E2E8F0', paddingTop: 12 }}>
                <strong>{delivery.recipientName}</strong>
                <p style={{ margin: '6px 0' }}>{delivery.channel}</p>
                <span style={badgeStyle}>
                  {delivery.status}
                  {delivery.deliveredAt ? ` • ${delivery.deliveredAt}` : ''}
                </span>
              </div>
            ))}
          </div>
        </section>
      </div>
    </DashboardShell>
  );
}
