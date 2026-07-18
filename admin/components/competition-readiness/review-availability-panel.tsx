'use client';

import { useTranslations } from 'next-intl';
import { FormEvent, useCallback, useEffect, useMemo, useState } from 'react';

import {
  cancelAvailabilitySlot,
  createAvailabilitySlot,
  listActiveCounsellors,
  listAvailabilitySlots,
  offerReviewSlots,
  type ActiveCounsellor,
  type AvailabilitySlot,
  type ReviewRequestDetail,
} from '../../lib/competition-readiness-api';
import {
  AdminCapability,
  hasAdminCapability,
} from '../../lib/admin-capabilities';
import { useLocale } from '../locale-provider';
import {
  Alert,
  Badge,
  Button,
  ConfirmDialog,
  Field,
  Input,
  Select,
} from '../ui';
import {
  formatDateTimeInZone,
  getApiErrorStatus,
  isEndpointUnavailable,
} from './readiness-utils';
import {
  canOfferReviewSlots,
  validateAvailabilityWindow,
  validateOfferExpiry,
  type AvailabilityValidationError,
  type OfferExpiryValidationError,
} from './review-actions';
import styles from './readiness.module.css';

type ConfirmedOperation =
  | { kind: 'cancel'; slot: AvailabilitySlot }
  | { kind: 'offer' }
  | null;

function randomKey(prefix: string): string {
  return `${prefix}:${globalThis.crypto.randomUUID()}`;
}

export function ReviewAvailabilityPanel({
  detail,
  role,
  onDetailUpdated,
}: Readonly<{
  detail: ReviewRequestDetail;
  role: string | undefined;
  onDetailUpdated: (detail: ReviewRequestDetail) => void;
}>) {
  const t = useTranslations('competitionReadiness');
  const { locale } = useLocale();
  const canManageOwn = hasAdminCapability(
    role,
    AdminCapability.ManageOwnAvailability,
  );
  const canManageAny = hasAdminCapability(
    role,
    AdminCapability.ManageCounsellorAvailability,
  );
  const canOffer = hasAdminCapability(role, AdminCapability.OfferReviewSlots);
  const [targetCounsellorId, setTargetCounsellorId] = useState(
    detail.assignedCounsellorId ?? '',
  );
  const [counsellors, setCounsellors] = useState<ActiveCounsellor[]>([]);
  const [counsellorsLoading, setCounsellorsLoading] = useState(false);
  const [slots, setSlots] = useState<AvailabilitySlot[]>([]);
  const [loading, setLoading] = useState(false);
  const [pending, setPending] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [confirmedOperation, setConfirmedOperation] =
    useState<ConfirmedOperation>(null);
  const [startsAt, setStartsAt] = useState('');
  const [endsAt, setEndsAt] = useState('');
  const [timezone, setTimezone] = useState(() => {
    try {
      return Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC';
    } catch {
      return 'UTC';
    }
  });
  const [capacity, setCapacity] = useState('1');
  const [slotValidation, setSlotValidation] =
    useState<AvailabilityValidationError | null>(null);
  const [selectedSlotIds, setSelectedSlotIds] = useState<string[]>([]);
  const [expiresAt, setExpiresAt] = useState('');
  const [expiryValidation, setExpiryValidation] =
    useState<OfferExpiryValidationError | null>(null);

  const loadCounsellors = useCallback(async () => {
    if (!canManageAny) return;
    setCounsellorsLoading(true);
    setError(null);
    try {
      const response = await listActiveCounsellors(true);
      setCounsellors(response.items);
    } catch (nextError) {
      setCounsellors([]);
      setError(errorMessage(nextError, t));
    } finally {
      setCounsellorsLoading(false);
    }
  }, [canManageAny, t]);

  useEffect(() => {
    void loadCounsellors();
  }, [loadCounsellors]);

  useEffect(() => {
    setTargetCounsellorId((current) => {
      if (detail.assignedCounsellorId) return detail.assignedCounsellorId;
      if (!current && counsellors.length === 1) return counsellors[0].id;
      return current;
    });
  }, [counsellors, detail.assignedCounsellorId]);

  const loadSlots = useCallback(async () => {
    if (!canManageOwn && !canManageAny) return;
    if (canManageAny && !targetCounsellorId) {
      setSlots([]);
      return;
    }
    setLoading(true);
    setError(null);
    try {
      const response = await listAvailabilitySlots({
        counsellorId: canManageAny ? targetCounsellorId : undefined,
        from: new Date().toISOString(),
        limit: 50,
      });
      setSlots(response.items);
      setSelectedSlotIds((current) =>
        current.filter((id) => response.items.some((slot) => slot.id === id)),
      );
    } catch (nextError) {
      setSlots([]);
      setError(errorMessage(nextError, t));
    } finally {
      setLoading(false);
    }
  }, [canManageAny, canManageOwn, t, targetCounsellorId]);

  useEffect(() => {
    void loadSlots();
  }, [loadSlots]);

  const selectedSlots = useMemo(
    () => slots.filter((slot) => selectedSlotIds.includes(slot.id)),
    [selectedSlotIds, slots],
  );
  const assignedTarget =
    Boolean(detail.assignedCounsellorId) &&
    targetCounsellorId === detail.assignedCounsellorId;
  const offerAllowed =
    canOffer &&
    assignedTarget &&
    canOfferReviewSlots(detail.status, detail.assignedCounsellorId);

  async function submitSlot(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const validation = validateAvailabilityWindow(
      startsAt,
      endsAt,
      timezone,
    );
    setSlotValidation(validation);
    if (validation || (canManageAny && !targetCounsellorId)) return;
    setPending('create');
    setError(null);
    setSuccess(null);
    try {
      await createAvailabilitySlot(
        {
          ...(canManageAny ? { counsellorId: targetCounsellorId } : {}),
          startsAt: startsAt.trim(),
          endsAt: endsAt.trim(),
          timezone: timezone.trim(),
          capacity: Number(capacity),
          reasonCode: 'review_availability_created',
        },
        randomKey('availability-slot'),
      );
      setStartsAt('');
      setEndsAt('');
      setSuccess(t('availabilityCreated'));
      await loadSlots();
    } catch (nextError) {
      setError(errorMessage(nextError, t));
    } finally {
      setPending(null);
    }
  }

  async function cancelSlot(slot: AvailabilitySlot) {
    setPending(`cancel:${slot.id}`);
    setError(null);
    setSuccess(null);
    try {
      await cancelAvailabilitySlot(slot.id, {
        expectedVersion: slot.version,
        reasonCode: 'review_availability_cancelled',
      });
      setConfirmedOperation(null);
      setSuccess(t('availabilityCancelled'));
      await loadSlots();
    } catch (nextError) {
      setError(errorMessage(nextError, t));
    } finally {
      setPending(null);
    }
  }

  function prepareOffer() {
    const validation = validateOfferExpiry(expiresAt, selectedSlots);
    setExpiryValidation(validation);
    if (!selectedSlots.length || validation) return;
    setConfirmedOperation({ kind: 'offer' });
  }

  async function submitOffer() {
    if (!offerAllowed || !selectedSlots.length) return;
    setPending('offer');
    setError(null);
    setSuccess(null);
    try {
      const updated = await offerReviewSlots(
        detail.id,
        {
          expectedVersion: detail.version,
          slotIds: selectedSlots.map((slot) => slot.id),
          expiresAt: expiresAt.trim(),
          reasonCode: 'review_call_slots_offered',
        },
        randomKey(`review-slot-offer:${detail.id}`),
      );
      setConfirmedOperation(null);
      setSelectedSlotIds([]);
      setExpiresAt('');
      setSuccess(t('slotsOffered'));
      onDetailUpdated(updated);
      await loadSlots();
    } catch (nextError) {
      setError(errorMessage(nextError, t));
    } finally {
      setPending(null);
    }
  }

  function toggleSlot(slotId: string) {
    setSelectedSlotIds((current) => {
      if (current.includes(slotId)) return current.filter((id) => id !== slotId);
      if (current.length >= 3) return current;
      return [...current, slotId];
    });
    setExpiryValidation(null);
  }

  if (!canManageOwn && !canManageAny) return null;

  return (
    <section className={`${styles.section} ${styles.schedulingSection}`}>
      <div className={styles.sectionHeader}>
        <div>
          <h4 className={styles.sectionTitle}>{t('availabilityTitle')}</h4>
          <p className={styles.panelSubtitle}>{t('availabilityDescription')}</p>
        </div>
        <Button
          variant="ghost"
          size="sm"
          loading={loading}
          onClick={() => void loadSlots()}
        >
          {t('refresh')}
        </Button>
      </div>

      {error ? <Alert variant="danger">{error}</Alert> : null}
      {success ? <Alert variant="success">{success}</Alert> : null}

      {canManageAny ? (
        <Field
          label={t('availabilityCounsellorLabel')}
          error={
            !targetCounsellorId && !counsellorsLoading
              ? t('counsellorRequired')
              : undefined
          }
        >
          {({ id, invalid }) => (
            <Select
              id={id}
              invalid={invalid}
              value={targetCounsellorId}
              disabled={counsellorsLoading}
              onChange={(event) => {
                setTargetCounsellorId(event.target.value);
                setSelectedSlotIds([]);
              }}
            >
              <option value="">{t('selectCounsellor')}</option>
              {counsellors.map((counsellor) => (
                <option key={counsellor.id} value={counsellor.id}>
                  {counsellor.fullName}
                  {counsellor.countryCode ? ` · ${counsellor.countryCode}` : ''}
                </option>
              ))}
            </Select>
          )}
        </Field>
      ) : null}

      <form className={styles.compactForm} onSubmit={submitSlot}>
        <Field
          label={t('slotStartsAtLabel')}
          error={
            slotValidation === 'invalid_datetime'
              ? t('explicitOffsetRequired')
              : slotValidation === 'start_not_future'
                ? t('slotMustBeFuture')
                : undefined
          }
        >
          {({ id, invalid }) => (
            <Input
              id={id}
              invalid={invalid}
              value={startsAt}
              placeholder="2026-08-02T09:00:00+01:00"
              onChange={(event) => {
                setStartsAt(event.target.value);
                setSlotValidation(null);
              }}
            />
          )}
        </Field>
        <Field
          label={t('slotEndsAtLabel')}
          error={
            slotValidation === 'invalid_datetime'
              ? t('explicitOffsetRequired')
              : slotValidation === 'end_before_start'
                ? t('slotEndAfterStart')
                : slotValidation === 'duration_too_long'
                  ? t('slotDurationMaximum')
                  : undefined
          }
        >
          {({ id, invalid }) => (
            <Input
              id={id}
              invalid={invalid}
              value={endsAt}
              placeholder="2026-08-02T10:00:00+01:00"
              onChange={(event) => {
                setEndsAt(event.target.value);
                setSlotValidation(null);
              }}
            />
          )}
        </Field>
        <Field
          label={t('slotTimezoneLabel')}
          error={
            slotValidation === 'invalid_timezone'
              ? t('invalidTimezone')
              : undefined
          }
        >
          {({ id, invalid }) => (
            <Input
              id={id}
              invalid={invalid}
              value={timezone}
              placeholder="Africa/Niamey"
              onChange={(event) => {
                setTimezone(event.target.value);
                setSlotValidation(null);
              }}
            />
          )}
        </Field>
        <Field label={t('slotCapacityLabel')}>
          {({ id, invalid }) => (
            <Input
              id={id}
              invalid={invalid}
              type="number"
              min={1}
              max={10}
              value={capacity}
              onChange={(event) => setCapacity(event.target.value)}
            />
          )}
        </Field>
        <div className={styles.formAction}>
          <Button
            type="submit"
            size="sm"
            loading={pending === 'create'}
            disabled={canManageAny && !targetCounsellorId}
          >
            {t('createAvailability')}
          </Button>
        </div>
      </form>
      <p className={styles.authorityNote}>{t('timezoneSafetyNote')}</p>

      <ul className={styles.slotList} aria-busy={loading}>
        {slots.length ? (
          slots.map((slot) => {
            const selectable =
              offerAllowed &&
              slot.status === 'available' &&
              slot.remainingCapacity > 0 &&
              new Date(slot.startsAt) > new Date();
            return (
              <li key={slot.id} className={styles.slotItem}>
                <label className={styles.slotChoice}>
                  <input
                    type="checkbox"
                    checked={selectedSlotIds.includes(slot.id)}
                    disabled={!selectable}
                    onChange={() => toggleSlot(slot.id)}
                  />
                  <span>
                    <strong>
                      {formatDateTimeInZone(slot.startsAt, locale, slot.timezone)}
                    </strong>
                    <span className={styles.panelSubtitle}>
                      {t('slotEndAndTimezone', {
                        end: formatDateTimeInZone(
                          slot.endsAt,
                          locale,
                          slot.timezone,
                        ),
                        timezone: slot.timezone,
                      })}
                    </span>
                  </span>
                </label>
                <div className={styles.slotMeta}>
                  <Badge
                    variant={
                      slot.status === 'available' ? 'success' : 'neutral'
                    }
                  >
                    {t(`availabilityStatus_${slot.status}`)}
                  </Badge>
                  <span className={styles.panelSubtitle}>
                    {t('remainingCapacity', {
                      remaining: slot.remainingCapacity,
                      capacity: slot.capacity,
                    })}
                  </span>
                  {slot.status !== 'cancelled' ? (
                    <Button
                      variant="ghost"
                      size="sm"
                      disabled={slot.bookedCount > 0}
                      loading={pending === `cancel:${slot.id}`}
                      onClick={() =>
                        setConfirmedOperation({ kind: 'cancel', slot })
                      }
                    >
                      {t('cancelAvailability')}
                    </Button>
                  ) : null}
                </div>
              </li>
            );
          })
        ) : (
          <li className={styles.panelSubtitle}>{t('noAvailabilitySlots')}</li>
        )}
      </ul>

      {offerAllowed ? (
        <div className={styles.offerBox}>
          <h5 className={styles.subsectionTitle}>{t('offerSlotsTitle')}</h5>
          <p className={styles.panelSubtitle}>{t('offerSlotsDescription')}</p>
          <Field
            label={t('offerExpiresAtLabel')}
            error={
              expiryValidation
                ? t(`offerExpiryError_${expiryValidation}`)
                : !selectedSlotIds.length
                  ? t('selectOneSlot')
                  : undefined
            }
          >
            {({ id, invalid }) => (
              <Input
                id={id}
                invalid={invalid}
                value={expiresAt}
                placeholder="2026-08-01T18:00:00+01:00"
                onChange={(event) => {
                  setExpiresAt(event.target.value);
                  setExpiryValidation(null);
                }}
              />
            )}
          </Field>
          <Button
            size="sm"
            disabled={!selectedSlotIds.length}
            onClick={prepareOffer}
          >
            {t('offerSelectedSlots', { count: selectedSlotIds.length })}
          </Button>
        </div>
      ) : canOffer && detail.assignedCounsellorId ? (
        <p className={styles.authorityNote}>{t('slotOfferStateUnavailable')}</p>
      ) : null}

      <ConfirmDialog
        open={confirmedOperation?.kind === 'cancel'}
        title={t('cancelAvailabilityConfirmTitle')}
        description={t('cancelAvailabilityConfirmDescription')}
        confirmLabel={t('cancelAvailability')}
        cancelLabel={t('cancel')}
        variant="danger"
        loading={
          confirmedOperation?.kind === 'cancel' &&
          pending === `cancel:${confirmedOperation.slot.id}`
        }
        onConfirm={() => {
          if (confirmedOperation?.kind === 'cancel') {
            void cancelSlot(confirmedOperation.slot);
          }
        }}
        onCancel={() => setConfirmedOperation(null)}
      />
      <ConfirmDialog
        open={confirmedOperation?.kind === 'offer'}
        title={t('offerSlotsConfirmTitle')}
        description={t('offerSlotsConfirmDescription', {
          count: selectedSlotIds.length,
          expiresAt,
        })}
        confirmLabel={t('confirmSlotOffer')}
        cancelLabel={t('cancel')}
        loading={pending === 'offer'}
        onConfirm={() => void submitOffer()}
        onCancel={() => setConfirmedOperation(null)}
      />
    </section>
  );
}

function errorMessage(
  error: unknown,
  t: (key: string) => string,
): string {
  const status = getApiErrorStatus(error);
  if (status === 403) return t('actionForbidden');
  if (status === 409) return t('actionConflict');
  if (isEndpointUnavailable(error)) return t('actionEndpointUnavailable');
  return t('actionFailed');
}
