import { prisma } from '../src/config/database';

async function main() {
  console.log('nothing to seed');
}

main()
  .catch(e => {
    console.error('Seeding failed:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
