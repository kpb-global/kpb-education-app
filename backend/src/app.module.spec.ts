import { Test, TestingModule } from '@nestjs/testing';

import { AppModule } from './app.module';
import { AdminCatalogController } from './modules/admin-catalog/admin-catalog.controller';
import { CaseMessagingGateway } from './modules/cases/case-messaging.gateway';

// Boot smoke test: compiling AppModule runs Nest's InstanceLoader over the whole
// provider/controller graph, so unresolved or circular dependencies fail here.
// `nest build` only type-checks and the per-service specs never wire the full
// module, so this is the only gate that catches a "compiles but won't boot"
// regression (e.g. the CasesService <-> CaseMessagingGateway circular dep).
describe('AppModule (boot smoke test)', () => {
  const originalDbUrl = process.env.DATABASE_URL;

  beforeAll(() => {
    // No DATABASE_URL => PrismaService stays in its disabled (no-connection)
    // mode, keeping the compile hermetic (no database required).
    delete process.env.DATABASE_URL;
  });

  afterAll(() => {
    if (originalDbUrl === undefined) {
      delete process.env.DATABASE_URL;
    } else {
      process.env.DATABASE_URL = originalDbUrl;
    }
  });

  it('resolves the full dependency graph', async () => {
    const moduleRef: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    // Spot-check the provider that previously failed to resolve (circular dep)
    // and a controller, to prove the graph is actually instantiated.
    expect(moduleRef.get(CaseMessagingGateway, { strict: false })).toBeDefined();
    expect(
      moduleRef.get(AdminCatalogController, { strict: false }),
    ).toBeDefined();

    await moduleRef.close();
  }, 30000);
});
