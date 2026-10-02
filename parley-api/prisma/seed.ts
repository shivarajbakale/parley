import { prisma } from '../src/config/database';

async function main() {
  console.log('Seeding database...\n');

  // 1. Create a demo user (idempotent on email)
  const user = await prisma.user.upsert({
    where: { email: 'demo@example.com' },
    update: {},
    create: {
      name: 'Demo User',
      email: 'demo@example.com',
    },
  });
  console.log(`  User: ${user.email}`);

  console.log('\nSeed complete!\n');
}

main()
  .catch(e => {
    console.error('Seeding failed:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
