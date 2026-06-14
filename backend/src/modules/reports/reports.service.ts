import { Injectable } from '@nestjs/common';

import { mockAdminData } from '../../common/data/mock-admin';

@Injectable()
export class ReportsService {
  getOverview() {
    return mockAdminData.reports.overview;
  }

  getFunnel() {
    return { items: mockAdminData.reports.funnel };
  }

  getCounselorPerformance() {
    return { items: mockAdminData.reports.counselorPerformance };
  }

  getCampaignPerformance() {
    return { items: mockAdminData.reports.campaignPerformance };
  }
}
