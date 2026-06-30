'use client';

import { FormEvent, useCallback, useEffect, useMemo, useState } from 'react';

import { DashboardShell } from '../../components/dashboard-shell';
import { apiFetch } from '../../lib/api-client';
import {
  badgeStyle,
  buttonStyle,
  inputStyle,
  labelStyle,
  mutedTextStyle,
  panelStyle,
} from '../../lib/ui';

interface AdminUserItem {
  id: string;
  fullName: string;
  email: string;
  role: string;
  isActive: boolean;
  languageScope: string[];
  workload: number;
}

function splitList(value: string) {
  return value
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean);
}

export default function UsersPage() {
  const [users, setUsers] = useState<AdminUserItem[]>([]);
  const [selectedUserId, setSelectedUserId] = useState<string | null>(null);
  const [statusMessage, setStatusMessage] = useState<string | null>(null);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
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

  const loadUsers = useCallback(async () => {
    setErrorMessage(null);
    try {
      const response = await apiFetch<{ items: AdminUserItem[] }>('/admin/users');
      setUsers(response.items);
      setSelectedUserId((current) => current ?? response.items[0]?.id ?? null);
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : 'Unable to load users.',
      );
    }
  }, []);

  useEffect(() => {
    void loadUsers();
  }, [loadUsers]);

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
    }
  }

  async function submitUpdate(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!selectedUser) {
      return;
    }

    setStatusMessage(null);
    setErrorMessage(null);

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
      await loadUsers();
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : 'Unable to update user.',
      );
    }
  }

  return (
    <DashboardShell title="Users and roles">
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

        <div style={{ display: 'grid', gap: 18, gridTemplateColumns: '1.1fr 0.9fr' }}>
          <section style={panelStyle}>
            <h3 style={{ marginTop: 0 }}>Internal operators</h3>
            <p style={mutedTextStyle}>
              Manage counselor, commercial, moderator, content, and admin access
              for the KPB team.
            </p>
            <div style={{ display: 'grid', gap: 12 }}>
              {users.map((user) => (
                <button
                  key={user.id}
                  onClick={() => setSelectedUserId(user.id)}
                  style={{
                    textAlign: 'left',
                    border:
                      selectedUserId === user.id
                        ? '2px solid #1D4ED8'
                        : '1px solid #E2E8F0',
                    borderRadius: 16,
                    padding: 14,
                    background: '#fff',
                    cursor: 'pointer',
                  }}
                >
                  <strong>{user.fullName}</strong>
                  <p style={{ margin: '6px 0' }}>
                    {user.role} • {user.email}
                  </p>
                  <span style={badgeStyle}>
                    {user.isActive ? 'active' : 'inactive'} • load {user.workload}
                  </span>
                </button>
              ))}
            </div>
          </section>

          <div style={{ display: 'grid', gap: 18 }}>
            <section style={{ ...panelStyle, display: 'grid', gap: 12 }}>
              <h3 style={{ marginTop: 0 }}>Create internal account</h3>
              <form onSubmit={submitCreate} style={{ display: 'grid', gap: 12 }}>
                <label style={labelStyle}>
                  Full name
                  <input
                    value={createForm.fullName}
                    onChange={(event) =>
                      setCreateForm((current) => ({
                        ...current,
                        fullName: event.target.value,
                      }))
                    }
                    style={inputStyle}
                  />
                </label>
                <label style={labelStyle}>
                  Email
                  <input
                    value={createForm.email}
                    onChange={(event) =>
                      setCreateForm((current) => ({
                        ...current,
                        email: event.target.value,
                      }))
                    }
                    style={inputStyle}
                  />
                </label>
                <label style={labelStyle}>
                  Role
                  <select
                    value={createForm.role}
                    onChange={(event) =>
                      setCreateForm((current) => ({
                        ...current,
                        role: event.target.value,
                      }))
                    }
                    style={inputStyle}
                  >
                    <option value="counselor">Counselor</option>
                    <option value="commercial">Commercial</option>
                    <option value="content_manager">Content manager</option>
                    <option value="moderator">Moderator</option>
                    <option value="admin">Admin</option>
                    <option value="super_admin">Super admin</option>
                  </select>
                </label>
                <label style={labelStyle}>
                  Language scope
                  <input
                    value={createForm.languageScope}
                    onChange={(event) =>
                      setCreateForm((current) => ({
                        ...current,
                        languageScope: event.target.value,
                      }))
                    }
                    style={inputStyle}
                  />
                </label>
                <label style={{ ...labelStyle, alignContent: 'end' }}>
                  <span>Active</span>
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
                </label>
                <button type="submit" style={buttonStyle}>
                  Create operator
                </button>
              </form>
            </section>

            {selectedUser ? (
              <section style={{ ...panelStyle, display: 'grid', gap: 12 }}>
                <h3 style={{ marginTop: 0 }}>Update selected operator</h3>
                <p style={mutedTextStyle}>
                  {selectedUser.fullName} • {selectedUser.email}
                </p>
                <form onSubmit={submitUpdate} style={{ display: 'grid', gap: 12 }}>
                  <label style={labelStyle}>
                    Role
                    <select
                      value={updateForm.role}
                      onChange={(event) =>
                        setUpdateForm((current) => ({
                          ...current,
                          role: event.target.value,
                        }))
                      }
                      style={inputStyle}
                    >
                      <option value="counselor">Counselor</option>
                      <option value="commercial">Commercial</option>
                      <option value="content_manager">Content manager</option>
                      <option value="moderator">Moderator</option>
                      <option value="admin">Admin</option>
                      <option value="super_admin">Super admin</option>
                    </select>
                  </label>
                  <label style={labelStyle}>
                    Workload
                    <input
                      value={updateForm.workload}
                      onChange={(event) =>
                        setUpdateForm((current) => ({
                          ...current,
                          workload: event.target.value,
                        }))
                      }
                      style={inputStyle}
                    />
                  </label>
                  <label style={{ ...labelStyle, alignContent: 'end' }}>
                    <span>Active</span>
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
                  </label>
                  <button type="submit" style={buttonStyle}>
                    Save role changes
                  </button>
                </form>
              </section>
            ) : null}
          </div>
        </div>
      </div>
    </DashboardShell>
  );
}
