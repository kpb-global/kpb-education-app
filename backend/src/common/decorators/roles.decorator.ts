import { SetMetadata } from '@nestjs/common';

import { InternalRole } from '../enums/internal-role.enum';

export const ROLES_KEY = 'roles';

export const Roles = (...roles: InternalRole[]) => SetMetadata(ROLES_KEY, roles);
