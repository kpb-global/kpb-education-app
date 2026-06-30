'use client';

import { FormEvent, useCallback, useEffect, useMemo, useState } from 'react';

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
  softPanelStyle,
  textareaStyle,
} from '../../lib/ui';

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

const visibleStatuses = ['submitted', 'documents_needed', 'counselor_assigned', 'in_progress', 'application_submitted', 'completed'];

const allStatuses = [
  'draft', 'submitted', 'under_review', 'documents_needed', 
  'counselor_assigned', 'awaiting_student', 'scheduled', 
  'in_progress', 'application_submitted', 'waiting_decision', 
  'awaiting_payment', 'completed', 'rejected', 'cancelled'
];

export default function CasesPage() {
  const { session } = useAdminAuth();
  const [cases, setCases] = useState<AdminCaseItem[]>([]);
  const [selectedCaseId, setSelectedCaseId] = useState<string | null>(null);
  const [statusMessage, setStatusMessage] = useState<string | null>(null);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
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

  const loadCases = useCallback(async () => {
    setErrorMessage(null);
    try {
      const response = await apiFetch<AdminCaseItem[]>('/admin/cases');
      setCases(response);
      setSelectedCaseId((current) => current ?? response[0]?.id ?? null);
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : 'Unable to load cases.',
      );
    }
  }, []);

  useEffect(() => {
    void loadCases();
  }, [loadCases]);

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

  async function submitStatus(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!selectedCase) {
      return;
    }

    setStatusMessage(null);
    setErrorMessage(null);
    try {
      await apiFetch(`/admin/cases/${selectedCase.id}`, {
        method: 'PATCH',
        body: {
          status: statusForm.status,
        },
      });
      setStatusMessage('Case status updated successfully.');
      await loadCases();
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : 'Unable to update case status.',
      );
    }
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

        <div
          style={{
            display: 'grid',
            gap: 16,
            gridTemplateColumns: 'repeat(4, minmax(0, 1fr))',
          }}
        >
          {visibleStatuses.map((status) => (
            <section key={status} style={softPanelStyle}>
              <h3 style={{ marginTop: 0, textTransform: 'capitalize' }}>
                {status.replaceAll('_', ' ')}
              </h3>
              <div style={{ display: 'grid', gap: 12 }}>
                {cases
                  .filter((item) => item.status === status)
                  .map((item) => (
                    <button
                      key={item.id}
                      onClick={() => setSelectedCaseId(item.id)}
                      style={{
                        textAlign: 'left',
                        border: selectedCaseId === item.id ? '2px solid #1D4ED8' : 'none',
                        borderRadius: 18,
                        padding: 16,
                        background: '#fff',
                        boxShadow: '0 12px 32px rgba(18,32,51,0.06)',
                        cursor: 'pointer',
                      }}
                    >
                      <strong>{item.referenceCode}</strong>
                      <p style={{ marginBottom: 6 }}>{item.studentName}</p>
                      <p style={{ margin: '6px 0', color: '#64748b' }}>
                        {item.type} • {item.contextLabel} • {item.preferredLanguage}
                      </p>
                      <p style={{ marginBottom: 0 }}>{item.nextStepTitle}</p>
                    </button>
                  ))}
              </div>
            </section>
          ))}
        </div>

        {selectedCase ? (
          <div style={{ display: 'grid', gap: 18, gridTemplateColumns: '1.15fr 0.85fr' }}>
            <section style={{ ...panelStyle, display: 'grid', gap: 16 }}>
              <div>
                <h3 style={{ marginTop: 0 }}>{selectedCase.referenceCode}</h3>
                <p style={{ margin: '6px 0' }}>
                  {selectedCase.studentName} • {selectedCase.studentEmail}
                </p>
                <span style={badgeStyle}>{selectedCase.status}</span>
              </div>
              <div>
                <strong>Next step</strong>
                <p style={{ margin: '8px 0 0', ...mutedTextStyle }}>
                  {selectedCase.nextStepTitle} — {selectedCase.nextStepDescription}
                </p>
              </div>
              <div>
                <strong>Timeline</strong>
                <div style={{ display: 'grid', gap: 12, marginTop: 10 }}>
                  {selectedCase.timeline.map((item) => (
                    <div key={item.id} style={{ borderTop: '1px solid #E2E8F0', paddingTop: 12 }}>
                      <strong>{item.title}</strong>
                      <p style={{ margin: '6px 0' }}>{item.description}</p>
                      <span style={badgeStyle}>{item.status}</span>
                    </div>
                  ))}
                </div>
              </div>
              <div>
                <strong>Internal notes</strong>
                <div style={{ display: 'grid', gap: 12, marginTop: 10 }}>
                  {selectedCase.internalNotes.map((item) => (
                    <div key={item.id} style={{ borderTop: '1px solid #E2E8F0', paddingTop: 12 }}>
                      <strong>
                        {item.authorName} • {item.authorRole}
                      </strong>
                      <p style={{ margin: '6px 0' }}>{item.body}</p>
                    </div>
                  ))}
                </div>
              </div>
            </section>

            <div style={{ display: 'grid', gap: 18 }}>
              <section style={{ ...panelStyle, display: 'grid', gap: 12 }}>
                <h3 style={{ marginTop: 0 }}>Update Status</h3>
                <form onSubmit={submitStatus} style={{ display: 'grid', gap: 12 }}>
                  <label style={labelStyle}>
                    Status
                    <select
                      value={statusForm.status}
                      onChange={(event) =>
                        setStatusForm({ status: event.target.value })
                      }
                      style={inputStyle}
                    >
                      {allStatuses.map((s) => (
                        <option key={s} value={s}>
                          {s.replaceAll('_', ' ')}
                        </option>
                      ))}
                    </select>
                  </label>
                  <button type="submit" style={buttonStyle}>
                    Update status
                  </button>
                </form>
              </section>

              <section style={{ ...panelStyle, display: 'grid', gap: 12 }}>
                <h3 style={{ marginTop: 0 }}>Assign counselor</h3>
                <form onSubmit={submitAssignment} style={{ display: 'grid', gap: 12 }}>
                  <label style={labelStyle}>
                    Advisor name
                    <input
                      value={assignForm.assignedAdvisorName}
                      onChange={(event) =>
                        setAssignForm((current) => ({
                          ...current,
                          assignedAdvisorName: event.target.value,
                        }))
                      }
                      style={inputStyle}
                    />
                  </label>
                  <label style={labelStyle}>
                    Phone
                    <input
                      value={assignForm.assignedAdvisorPhone}
                      onChange={(event) =>
                        setAssignForm((current) => ({
                          ...current,
                          assignedAdvisorPhone: event.target.value,
                        }))
                      }
                      style={inputStyle}
                    />
                  </label>
                  <label style={labelStyle}>
                    WhatsApp
                    <input
                      value={assignForm.assignedAdvisorWhatsapp}
                      onChange={(event) =>
                        setAssignForm((current) => ({
                          ...current,
                          assignedAdvisorWhatsapp: event.target.value,
                        }))
                      }
                      style={inputStyle}
                    />
                  </label>
                  <label style={labelStyle}>
                    Next step title
                    <input
                      value={assignForm.nextStepTitle}
                      onChange={(event) =>
                        setAssignForm((current) => ({
                          ...current,
                          nextStepTitle: event.target.value,
                        }))
                      }
                      style={inputStyle}
                    />
                  </label>
                  <label style={labelStyle}>
                    Next step description
                    <textarea
                      value={assignForm.nextStepDescription}
                      onChange={(event) =>
                        setAssignForm((current) => ({
                          ...current,
                          nextStepDescription: event.target.value,
                        }))
                      }
                      style={textareaStyle}
                    />
                  </label>
                  <label style={labelStyle}>
                    Scheduled at
                    <input
                      type="datetime-local"
                      value={assignForm.scheduledAt}
                      onChange={(event) =>
                        setAssignForm((current) => ({
                          ...current,
                          scheduledAt: event.target.value,
                        }))
                      }
                      style={inputStyle}
                    />
                  </label>
                  <button type="submit" style={buttonStyle}>
                    Save assignment
                  </button>
                </form>
              </section>

              <section style={{ ...panelStyle, display: 'grid', gap: 12 }}>
                <h3 style={{ marginTop: 0 }}>Create task</h3>
                <form onSubmit={submitTask} style={{ display: 'grid', gap: 12 }}>
                  <label style={labelStyle}>
                    Task title
                    <input
                      value={taskForm.title}
                      onChange={(event) =>
                        setTaskForm((current) => ({
                          ...current,
                          title: event.target.value,
                        }))
                      }
                      style={inputStyle}
                    />
                  </label>
                  <label style={labelStyle}>
                    Assignee name
                    <input
                      value={taskForm.assigneeName}
                      onChange={(event) =>
                        setTaskForm((current) => ({
                          ...current,
                          assigneeName: event.target.value,
                        }))
                      }
                      style={inputStyle}
                    />
                  </label>
                  <label style={labelStyle}>
                    Assignee role
                    <input
                      value={taskForm.assigneeRole}
                      onChange={(event) =>
                        setTaskForm((current) => ({
                          ...current,
                          assigneeRole: event.target.value,
                        }))
                      }
                      style={inputStyle}
                    />
                  </label>
                  <label style={labelStyle}>
                    Due at
                    <input
                      type="datetime-local"
                      value={taskForm.dueAt}
                      onChange={(event) =>
                        setTaskForm((current) => ({
                          ...current,
                          dueAt: event.target.value,
                        }))
                      }
                      style={inputStyle}
                    />
                  </label>
                  <button type="submit" style={buttonStyle}>
                    Add task
                  </button>
                </form>
                <div style={{ display: 'grid', gap: 12 }}>
                  {selectedCase.tasks.map((task) => (
                    <div key={task.id} style={{ borderTop: '1px solid #E2E8F0', paddingTop: 12 }}>
                      <strong>{task.title}</strong>
                      <p style={{ margin: '6px 0' }}>
                        {task.assigneeName ?? 'Unassigned'} • {task.status}
                      </p>
                    </div>
                  ))}
                </div>
              </section>

              <section style={{ ...panelStyle, display: 'grid', gap: 12 }}>
                <h3 style={{ marginTop: 0 }}>Add internal note</h3>
                <form onSubmit={submitNote} style={{ display: 'grid', gap: 12 }}>
                  <label style={labelStyle}>
                    Note
                    <textarea
                      value={noteForm.body}
                      onChange={(event) =>
                        setNoteForm({ body: event.target.value })
                      }
                      style={textareaStyle}
                    />
                  </label>
                  <button type="submit" style={buttonStyle}>
                    Save note
                  </button>
                </form>
              </section>
            </div>
          </div>
        ) : null}
      </div>
    </DashboardShell>
  );
}
