'use client';

import { FormEvent, useEffect, useMemo, useState } from 'react';

import { useAdminAuth } from '../../components/admin-auth-provider';
import { DashboardShell } from '../../components/dashboard-shell';
import {
  Alert,
  Button,
  Card,
  ConfirmDialog,
  Field,
  Input,
  Select,
  StatusBadge,
  Textarea,
} from '../../components/ui';
import { apiFetch } from '../../lib/api-client';
import { mutedTextStyle, softPanelStyle } from '../../lib/ui';

interface CaseTaskItem {
  id: string;
  title: string;
  assigneeName: string | null;
  status: string;
  dueAt: string | null;
}

interface CaseNoteItem {
  id: string;
  authorName: string;
  authorRole: string;
  body: string;
  createdAt: string;
}

interface CaseTimelineItem {
  id: string;
  title: string;
  description: string;
  status: string;
  createdAt: string;
}

interface AdminCaseItem {
  id: string;
  referenceCode: string;
  studentName: string;
  studentEmail: string;
  preferredLanguage: string;
  type: string;
  status: string;
  contextLabel: string;
  assignedAdvisorName: string | null;
  nextStepTitle: string;
  nextStepDescription: string;
  tasks: CaseTaskItem[];
  internalNotes: CaseNoteItem[];
  timeline: CaseTimelineItem[];
}

const visibleStatuses = [
  'submitted',
  'documents_needed',
  'counselor_assigned',
  'in_progress',
  'application_submitted',
  'completed',
];

const allStatuses = [
  'draft',
  'submitted',
  'under_review',
  'documents_needed',
  'counselor_assigned',
  'awaiting_student',
  'scheduled',
  'in_progress',
  'application_submitted',
  'waiting_decision',
  'awaiting_payment',
  'completed',
  'rejected',
  'cancelled',
];

// Setting a case to one of these is consequential — confirm before applying.
const DESTRUCTIVE_STATUSES = new Set(['rejected', 'cancelled']);

export default function CasesPage() {
  const { session } = useAdminAuth();
  const [cases, setCases] = useState<AdminCaseItem[]>([]);
  const [selectedCaseId, setSelectedCaseId] = useState<string | null>(null);
  const [statusMessage, setStatusMessage] = useState<string | null>(null);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [savingStatus, setSavingStatus] = useState(false);
  const [confirmStatus, setConfirmStatus] = useState(false);
  const [assignForm, setAssignForm] = useState({
    assignedAdvisorName: '',
    assignedAdvisorPhone: '',
    assignedAdvisorWhatsapp: '',
    nextStepTitle: '',
    nextStepDescription: '',
    scheduledAt: '',
  });
  const [taskForm, setTaskForm] = useState({
    title: '',
    assigneeName: '',
    assigneeRole: 'counselor',
    dueAt: '',
    status: 'open',
  });
  const [noteForm, setNoteForm] = useState({
    body: '',
  });
  const [statusForm, setStatusForm] = useState({
    status: '',
  });

  async function loadCases() {
    setErrorMessage(null);
    try {
      const response = await apiFetch<AdminCaseItem[]>('/admin/cases');
      setCases(response);
      if (!selectedCaseId && response[0]) {
        setSelectedCaseId(response[0].id);
      }
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : 'Unable to load cases.',
      );
    }
  }

  useEffect(() => {
    // Don't fire authenticated admin requests until a session exists,
    // otherwise the page issues token-less calls while unauthenticated.
    if (!session) {
      return;
    }
    void loadCases();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [session]);

  const selectedCase = useMemo(
    () => cases.find((item) => item.id === selectedCaseId) ?? null,
    [cases, selectedCaseId],
  );

  useEffect(() => {
    if (!selectedCase) {
      return;
    }
    setAssignForm({
      assignedAdvisorName: selectedCase.assignedAdvisorName ?? '',
      assignedAdvisorPhone: '',
      assignedAdvisorWhatsapp: '',
      nextStepTitle: selectedCase.nextStepTitle,
      nextStepDescription: selectedCase.nextStepDescription,
      scheduledAt: '',
    });
    setStatusForm({
      status: selectedCase.status,
    });
  }, [selectedCase]);

  async function submitAssignment(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!selectedCase) {
      return;
    }

    setStatusMessage(null);
    setErrorMessage(null);
    try {
      await apiFetch(`/admin/cases/${selectedCase.id}/assign`, {
        method: 'POST',
        body: {
          assignedAdvisorName: assignForm.assignedAdvisorName,
          assignedAdvisorPhone: assignForm.assignedAdvisorPhone || undefined,
          assignedAdvisorWhatsapp:
            assignForm.assignedAdvisorWhatsapp || undefined,
          nextStepTitle: assignForm.nextStepTitle || undefined,
          nextStepDescription: assignForm.nextStepDescription || undefined,
          scheduledAt: assignForm.scheduledAt
            ? new Date(assignForm.scheduledAt).toISOString()
            : undefined,
        },
      });
      setStatusMessage('Case assignment updated successfully.');
      await loadCases();
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : 'Unable to assign case.',
      );
    }
  }

  async function applyStatus() {
    if (!selectedCase) {
      return;
    }
    setStatusMessage(null);
    setErrorMessage(null);
    setSavingStatus(true);
    try {
      await apiFetch(`/admin/cases/${selectedCase.id}`, {
        method: 'PATCH',
        body: {
          status: statusForm.status,
        },
      });
      setStatusMessage('Case status updated successfully.');
      setConfirmStatus(false);
      await loadCases();
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : 'Unable to update case status.',
      );
    } finally {
      setSavingStatus(false);
    }
  }

  function submitStatus(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!selectedCase) {
      return;
    }
    if (
      DESTRUCTIVE_STATUSES.has(statusForm.status) &&
      statusForm.status !== selectedCase.status
    ) {
      setConfirmStatus(true);
      return;
    }
    void applyStatus();
  }

  async function submitTask(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!selectedCase) {
      return;
    }

    setStatusMessage(null);
    setErrorMessage(null);
    try {
      await apiFetch(`/admin/cases/${selectedCase.id}/tasks`, {
        method: 'POST',
        body: {
          title: taskForm.title,
          assigneeName: taskForm.assigneeName || undefined,
          assigneeRole: taskForm.assigneeRole || undefined,
          dueAt: taskForm.dueAt
            ? new Date(taskForm.dueAt).toISOString()
            : undefined,
          status: taskForm.status,
        },
      });
      setTaskForm({
        title: '',
        assigneeName: '',
        assigneeRole: 'counselor',
        dueAt: '',
        status: 'open',
      });
      setStatusMessage('Task added to the selected case.');
      await loadCases();
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : 'Unable to create task.',
      );
    }
  }

  async function submitNote(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!selectedCase || !session) {
      return;
    }

    setStatusMessage(null);
    setErrorMessage(null);
    try {
      await apiFetch(`/admin/cases/${selectedCase.id}/internal-notes`, {
        method: 'POST',
        body: {
          authorName: session.user.fullName,
          authorRole: session.user.role,
          body: noteForm.body,
        },
      });
      setNoteForm({ body: '' });
      setStatusMessage('Internal note added to the case.');
      await loadCases();
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : 'Unable to create note.',
      );
    }
  }

  return (
    <DashboardShell title="Cases">
      <div style={{ display: 'grid', gap: 'var(--space-5)' }}>
        {statusMessage ? <Alert variant="success">{statusMessage}</Alert> : null}
        {errorMessage ? <Alert variant="danger">{errorMessage}</Alert> : null}

        <div
          style={{
            display: 'grid',
            gap: 'var(--space-4)',
            gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))',
          }}
        >
          {visibleStatuses.map((status) => (
            <section key={status} style={softPanelStyle}>
              <h3 style={{ marginTop: 0, textTransform: 'capitalize' }}>
                {status.replaceAll('_', ' ')}
              </h3>
              <div style={{ display: 'grid', gap: 'var(--space-3)' }}>
                {cases
                  .filter((item) => item.status === status)
                  .map((item) => (
                    <button
                      key={item.id}
                      type="button"
                      onClick={() => setSelectedCaseId(item.id)}
                      aria-pressed={selectedCaseId === item.id}
                      aria-label={`${item.referenceCode} — ${item.studentName}`}
                      style={{
                        textAlign: 'left',
                        border:
                          selectedCaseId === item.id
                            ? '2px solid var(--brand)'
                            : '1px solid var(--border)',
                        borderRadius: 'var(--radius-md)',
                        padding: 'var(--space-3)',
                        background: 'var(--surface)',
                        boxShadow: 'var(--shadow-sm)',
                        cursor: 'pointer',
                        display: 'grid',
                        gap: 'var(--space-1)',
                      }}
                    >
                      <strong>{item.referenceCode}</strong>
                      <span>{item.studentName}</span>
                      <span style={{ ...mutedTextStyle, fontSize: 'var(--text-xs)' }}>
                        {item.type} • {item.contextLabel} • {item.preferredLanguage}
                      </span>
                      <span style={{ fontSize: 'var(--text-sm)' }}>
                        {item.nextStepTitle}
                      </span>
                    </button>
                  ))}
              </div>
            </section>
          ))}
        </div>

        {selectedCase ? (
          <div
            style={{
              display: 'grid',
              gap: 'var(--space-5)',
              gridTemplateColumns: '1.15fr 0.85fr',
            }}
          >
            <Card style={{ display: 'grid', gap: 'var(--space-4)' }}>
              <div style={{ display: 'grid', gap: 'var(--space-2)' }}>
                <h3 style={{ margin: 0 }}>{selectedCase.referenceCode}</h3>
                <span style={mutedTextStyle}>
                  {selectedCase.studentName} • {selectedCase.studentEmail}
                </span>
                <span>
                  <StatusBadge status={selectedCase.status} />
                </span>
              </div>
              <div>
                <strong>Next step</strong>
                <p style={{ margin: '8px 0 0', ...mutedTextStyle }}>
                  {selectedCase.nextStepTitle} — {selectedCase.nextStepDescription}
                </p>
              </div>
              <div>
                <strong>Timeline</strong>
                <div style={{ display: 'grid', gap: 'var(--space-3)', marginTop: 10 }}>
                  {selectedCase.timeline.map((item) => (
                    <div
                      key={item.id}
                      style={{
                        borderTop: '1px solid var(--border)',
                        paddingTop: 'var(--space-3)',
                        display: 'grid',
                        gap: 'var(--space-2)',
                      }}
                    >
                      <strong>{item.title}</strong>
                      <p style={{ margin: 0 }}>{item.description}</p>
                      <span>
                        <StatusBadge status={item.status} />
                      </span>
                    </div>
                  ))}
                </div>
              </div>
              <div>
                <strong>Internal notes</strong>
                <div style={{ display: 'grid', gap: 'var(--space-3)', marginTop: 10 }}>
                  {selectedCase.internalNotes.map((item) => (
                    <div
                      key={item.id}
                      style={{
                        borderTop: '1px solid var(--border)',
                        paddingTop: 'var(--space-3)',
                      }}
                    >
                      <strong>
                        {item.authorName} • {item.authorRole}
                      </strong>
                      <p style={{ margin: '6px 0 0' }}>{item.body}</p>
                    </div>
                  ))}
                </div>
              </div>
            </Card>

            <div style={{ display: 'grid', gap: 'var(--space-5)' }}>
              <Card style={{ display: 'grid', gap: 'var(--space-3)' }}>
                <h3 style={{ marginTop: 0 }}>Update status</h3>
                <form onSubmit={submitStatus} style={{ display: 'grid', gap: 'var(--space-3)' }}>
                  <Field label="Status">
                    {({ id }) => (
                      <Select
                        id={id}
                        value={statusForm.status}
                        onChange={(event) =>
                          setStatusForm({ status: event.target.value })
                        }
                      >
                        {allStatuses.map((s) => (
                          <option key={s} value={s}>
                            {s.replaceAll('_', ' ')}
                          </option>
                        ))}
                      </Select>
                    )}
                  </Field>
                  <Button type="submit" loading={savingStatus}>
                    Update status
                  </Button>
                </form>
              </Card>

              <Card style={{ display: 'grid', gap: 'var(--space-3)' }}>
                <h3 style={{ marginTop: 0 }}>Assign counselor</h3>
                <form onSubmit={submitAssignment} style={{ display: 'grid', gap: 'var(--space-3)' }}>
                  <Field label="Advisor name">
                    {({ id }) => (
                      <Input
                        id={id}
                        value={assignForm.assignedAdvisorName}
                        onChange={(event) =>
                          setAssignForm((current) => ({
                            ...current,
                            assignedAdvisorName: event.target.value,
                          }))
                        }
                      />
                    )}
                  </Field>
                  <Field label="Phone">
                    {({ id }) => (
                      <Input
                        id={id}
                        value={assignForm.assignedAdvisorPhone}
                        onChange={(event) =>
                          setAssignForm((current) => ({
                            ...current,
                            assignedAdvisorPhone: event.target.value,
                          }))
                        }
                      />
                    )}
                  </Field>
                  <Field label="WhatsApp">
                    {({ id }) => (
                      <Input
                        id={id}
                        value={assignForm.assignedAdvisorWhatsapp}
                        onChange={(event) =>
                          setAssignForm((current) => ({
                            ...current,
                            assignedAdvisorWhatsapp: event.target.value,
                          }))
                        }
                      />
                    )}
                  </Field>
                  <Field label="Next step title">
                    {({ id }) => (
                      <Input
                        id={id}
                        value={assignForm.nextStepTitle}
                        onChange={(event) =>
                          setAssignForm((current) => ({
                            ...current,
                            nextStepTitle: event.target.value,
                          }))
                        }
                      />
                    )}
                  </Field>
                  <Field label="Next step description">
                    {({ id }) => (
                      <Textarea
                        id={id}
                        value={assignForm.nextStepDescription}
                        onChange={(event) =>
                          setAssignForm((current) => ({
                            ...current,
                            nextStepDescription: event.target.value,
                          }))
                        }
                      />
                    )}
                  </Field>
                  <Field label="Scheduled at">
                    {({ id }) => (
                      <Input
                        id={id}
                        type="datetime-local"
                        value={assignForm.scheduledAt}
                        onChange={(event) =>
                          setAssignForm((current) => ({
                            ...current,
                            scheduledAt: event.target.value,
                          }))
                        }
                      />
                    )}
                  </Field>
                  <Button type="submit">Save assignment</Button>
                </form>
              </Card>

              <Card style={{ display: 'grid', gap: 'var(--space-3)' }}>
                <h3 style={{ marginTop: 0 }}>Create task</h3>
                <form onSubmit={submitTask} style={{ display: 'grid', gap: 'var(--space-3)' }}>
                  <Field label="Task title">
                    {({ id }) => (
                      <Input
                        id={id}
                        value={taskForm.title}
                        onChange={(event) =>
                          setTaskForm((current) => ({
                            ...current,
                            title: event.target.value,
                          }))
                        }
                      />
                    )}
                  </Field>
                  <Field label="Assignee name">
                    {({ id }) => (
                      <Input
                        id={id}
                        value={taskForm.assigneeName}
                        onChange={(event) =>
                          setTaskForm((current) => ({
                            ...current,
                            assigneeName: event.target.value,
                          }))
                        }
                      />
                    )}
                  </Field>
                  <Field label="Assignee role">
                    {({ id }) => (
                      <Input
                        id={id}
                        value={taskForm.assigneeRole}
                        onChange={(event) =>
                          setTaskForm((current) => ({
                            ...current,
                            assigneeRole: event.target.value,
                          }))
                        }
                      />
                    )}
                  </Field>
                  <Field label="Due at">
                    {({ id }) => (
                      <Input
                        id={id}
                        type="datetime-local"
                        value={taskForm.dueAt}
                        onChange={(event) =>
                          setTaskForm((current) => ({
                            ...current,
                            dueAt: event.target.value,
                          }))
                        }
                      />
                    )}
                  </Field>
                  <Button type="submit">Add task</Button>
                </form>
                <div style={{ display: 'grid', gap: 'var(--space-3)' }}>
                  {selectedCase.tasks.map((task) => (
                    <div
                      key={task.id}
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
                        <strong>{task.title}</strong>
                        <span style={{ ...mutedTextStyle, marginLeft: 8 }}>
                          {task.assigneeName ?? 'Unassigned'}
                        </span>
                      </span>
                      <StatusBadge status={task.status} />
                    </div>
                  ))}
                </div>
              </Card>

              <Card style={{ display: 'grid', gap: 'var(--space-3)' }}>
                <h3 style={{ marginTop: 0 }}>Add internal note</h3>
                <form onSubmit={submitNote} style={{ display: 'grid', gap: 'var(--space-3)' }}>
                  <Field label="Note">
                    {({ id }) => (
                      <Textarea
                        id={id}
                        value={noteForm.body}
                        onChange={(event) => setNoteForm({ body: event.target.value })}
                      />
                    )}
                  </Field>
                  <Button type="submit">Save note</Button>
                </form>
              </Card>
            </div>
          </div>
        ) : null}
      </div>

      <ConfirmDialog
        open={confirmStatus}
        title={`Set this case to "${statusForm.status.replaceAll('_', ' ')}"?`}
        description={
          selectedCase
            ? `Case ${selectedCase.referenceCode} for ${selectedCase.studentName} will be marked as ${statusForm.status.replaceAll('_', ' ')}.`
            : undefined
        }
        confirmLabel="Apply"
        cancelLabel="Cancel"
        variant="danger"
        loading={savingStatus}
        onConfirm={() => void applyStatus()}
        onCancel={() => setConfirmStatus(false)}
      />
    </DashboardShell>
  );
}
