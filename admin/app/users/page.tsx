'use client';

import { FormEvent, useEffect, useMemo, useState } from 'react';

import { useAdminAuth } from '../../components/admin-auth-provider';
import { DashboardShell } from '../../components/dashboard-shell';
import {
  Alert,
  Badge,
  Button,
  Card,
  ConfirmDialog,
  Field,
  Input,
  Select,
} from '../../components/ui';
import { apiFetch } from '../../lib/api-client';
import { mutedTextStyle } from '../../lib/ui';

interface AdminUserItem {
  id: string;
  fullName: string;
  email: string;
  role: string;
  isActive: boolean;
  languageScope: string[];
  workload: number;
}

const ROLE_OPTIONS = [
  { value: 'counselor', label: 'Counselor' },
  { value: 'commercial', label: 'Commercial' },
  { value: 'content_manager', label: 'Content manager' },
  { value: 'moderator', label: 'Moderator' },
  { value: 'admin', label: 'Admin' },
  { value: 'super_admin', label: 'Super admin' },
];

function splitList(value: string) {
  return value
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean);
}

export default function UsersPage() {
  const { session } = useAdminAuth();
  const [users, setUsers] = useState<AdminUserItem[]>([]);
  const [selectedUserId, setSelectedUserId] = useState<string | null>(null);
  const [statusMessage, setStatusMessage] = useState<string | null>(null);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [creating, setCreating] = useState(false);
  const [saving, setSaving] = useState(false);
  const [confirmDeactivate, setConfirmDeactivate] = useState(false);
  const [createForm, setCreateForm] = useState({
    fullName: '',
    email: '',
    role: 'counselor',
    languageScope: 'fr,en',
    isActive: true,
  });
  const [updateForm, setUpdateForm] = useState({
    role: 'counselor',
    isActive: true,
    workload: '0',
  });

  async function loadUsers() {
    setErrorMessage(null);
    try {
      const response = await apiFetch<{ items: AdminUserItem[] }>('/admin/users');
      setUsers(response.items);
      if (!selectedUserId && response.items[0]) {
        setSelectedUserId(response.items[0].id);
      }
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : 'Unable to load users.',
      );
    }
  }

  useEffect(() => {
    if (!session) {
      return;
    }
    void loadUsers();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [session]);

  const selectedUser = useMemo(
    () => users.find((item) => item.id === selectedUserId) ?? null,
    [selectedUserId, users],
  );

  useEffect(() => {
    if (!selectedUser) {
      return;
    }
    setUpdateForm({
      role: selectedUser.role,
      isActive: selectedUser.isActive,
      workload: String(selectedUser.workload),
    });
  }, [selectedUser]);

  async function submitCreate(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setStatusMessage(null);
    setErrorMessage(null);
    setCreating(true);

    try {
      await apiFetch('/admin/users', {
        method: 'POST',
        body: {
          fullName: createForm.fullName,
          email: createForm.email,
          role: createForm.role,
          languageScope: splitList(createForm.languageScope),
          isActive: createForm.isActive,
        },
      });
      setCreateForm({
        fullName: '',
        email: '',
        role: 'counselor',
        languageScope: 'fr,en',
        isActive: true,
      });
      setStatusMessage('Internal operator created.');
      await loadUsers();
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : 'Unable to create user.',
      );
    } finally {
      setCreating(false);
    }
  }

  async function applyUpdate() {
    if (!selectedUser) {
      return;
    }
    setStatusMessage(null);
    setErrorMessage(null);
    setSaving(true);

    try {
      await apiFetch(`/admin/users/${selectedUser.id}`, {
        method: 'PATCH',
        body: {
          role: updateForm.role,
          isActive: updateForm.isActive,
          workload: Number(updateForm.workload),
        },
      });
      setStatusMessage('User role and activation updated.');
      setConfirmDeactivate(false);
      await loadUsers();
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : 'Unable to update user.',
      );
    } finally {
      setSaving(false);
    }
  }

  function submitUpdate(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!selectedUser) {
      return;
    }
    // Deactivating a teammate is consequential — confirm first.
    if (selectedUser.isActive && !updateForm.isActive) {
      setConfirmDeactivate(true);
      return;
    }
    void applyUpdate();
  }

  return (
    <DashboardShell title="Users and roles">
      <div style={{ display: 'grid', gap: 'var(--space-5)' }}>
        {statusMessage ? <Alert variant="success">{statusMessage}</Alert> : null}
        {errorMessage ? <Alert variant="danger">{errorMessage}</Alert> : null}

        <div
          style={{
            display: 'grid',
            gap: 'var(--space-5)',
            gridTemplateColumns: '1.1fr 0.9fr',
          }}
        >
          <Card>
            <h3 style={{ marginTop: 0 }}>Internal operators</h3>
            <p style={mutedTextStyle}>
              Manage counselor, commercial, moderator, content, and admin access
              for the KPB team.
            </p>
            <div style={{ display: 'grid', gap: 'var(--space-3)' }}>
              {users.map((user) => (
                <button
                  key={user.id}
                  type="button"
                  onClick={() => setSelectedUserId(user.id)}
                  aria-pressed={selectedUserId === user.id}
                  style={{
                    textAlign: 'left',
                    border:
                      selectedUserId === user.id
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
                  <strong>{user.fullName}</strong>
                  <span style={{ ...mutedTextStyle, fontSize: 'var(--text-sm)' }}>
                    {user.role} • {user.email}
                  </span>
                  <span style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
                    <Badge variant={user.isActive ? 'success' : 'neutral'}>
                      {user.isActive ? 'active' : 'inactive'}
                    </Badge>
                    <span style={{ ...mutedTextStyle, fontSize: 'var(--text-xs)' }}>
                      load {user.workload}
                    </span>
                  </span>
                </button>
              ))}
            </div>
          </Card>

          <div style={{ display: 'grid', gap: 'var(--space-5)' }}>
            <Card style={{ display: 'grid', gap: 'var(--space-3)' }}>
              <h3 style={{ marginTop: 0 }}>Create internal account</h3>
              <form onSubmit={submitCreate} style={{ display: 'grid', gap: 'var(--space-3)' }}>
                <Field label="Full name">
                  {({ id }) => (
                    <Input
                      id={id}
                      value={createForm.fullName}
                      onChange={(event) =>
                        setCreateForm((current) => ({
                          ...current,
                          fullName: event.target.value,
                        }))
                      }
                    />
                  )}
                </Field>
                <Field label="Email">
                  {({ id }) => (
                    <Input
                      id={id}
                      type="email"
                      value={createForm.email}
                      onChange={(event) =>
                        setCreateForm((current) => ({
                          ...current,
                          email: event.target.value,
                        }))
                      }
                    />
                  )}
                </Field>
                <Field label="Role">
                  {({ id }) => (
                    <Select
                      id={id}
                      value={createForm.role}
                      onChange={(event) =>
                        setCreateForm((current) => ({
                          ...current,
                          role: event.target.value,
                        }))
                      }
                    >
                      {ROLE_OPTIONS.map((option) => (
                        <option key={option.value} value={option.value}>
                          {option.label}
                        </option>
                      ))}
                    </Select>
                  )}
                </Field>
                <Field label="Language scope (comma-separated)">
                  {({ id }) => (
                    <Input
                      id={id}
                      value={createForm.languageScope}
                      onChange={(event) =>
                        setCreateForm((current) => ({
                          ...current,
                          languageScope: event.target.value,
                        }))
                      }
                    />
                  )}
                </Field>
                <label style={{ display: 'flex', gap: 'var(--space-2)', alignItems: 'center', fontWeight: 600 }}>
                  <input
                    type="checkbox"
                    checked={createForm.isActive}
                    onChange={(event) =>
                      setCreateForm((current) => ({
                        ...current,
                        isActive: event.target.checked,
                      }))
                    }
                  />
                  Active
                </label>
                <Button type="submit" loading={creating}>
                  Create operator
                </Button>
              </form>
            </Card>

            {selectedUser ? (
              <Card style={{ display: 'grid', gap: 'var(--space-3)' }}>
                <h3 style={{ marginTop: 0 }}>Update selected operator</h3>
                <p style={mutedTextStyle}>
                  {selectedUser.fullName} • {selectedUser.email}
                </p>
                <form onSubmit={submitUpdate} style={{ display: 'grid', gap: 'var(--space-3)' }}>
                  <Field label="Role">
                    {({ id }) => (
                      <Select
                        id={id}
                        value={updateForm.role}
                        onChange={(event) =>
                          setUpdateForm((current) => ({
                            ...current,
                            role: event.target.value,
                          }))
                        }
                      >
                        {ROLE_OPTIONS.map((option) => (
                          <option key={option.value} value={option.value}>
                            {option.label}
                          </option>
                        ))}
                      </Select>
                    )}
                  </Field>
                  <Field label="Workload">
                    {({ id }) => (
                      <Input
                        id={id}
                        type="number"
                        value={updateForm.workload}
                        onChange={(event) =>
                          setUpdateForm((current) => ({
                            ...current,
                            workload: event.target.value,
                          }))
                        }
                      />
                    )}
                  </Field>
                  <label style={{ display: 'flex', gap: 'var(--space-2)', alignItems: 'center', fontWeight: 600 }}>
                    <input
                      type="checkbox"
                      checked={updateForm.isActive}
                      onChange={(event) =>
                        setUpdateForm((current) => ({
                          ...current,
                          isActive: event.target.checked,
                        }))
                      }
                    />
                    Active
                  </label>
                  <Button type="submit" loading={saving}>
                    Save role changes
                  </Button>
                </form>
              </Card>
            ) : null}
          </div>
        </div>
      </div>

      <ConfirmDialog
        open={confirmDeactivate}
        title="Deactivate this operator?"
        description={
          selectedUser
            ? `${selectedUser.fullName} will lose access to the admin workspace until reactivated.`
            : undefined
        }
        confirmLabel="Deactivate"
        cancelLabel="Cancel"
        variant="danger"
        loading={saving}
        onConfirm={() => void applyUpdate()}
        onCancel={() => setConfirmDeactivate(false)}
      />
    </DashboardShell>
  );
}
