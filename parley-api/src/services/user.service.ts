import { AppError } from '../middleware/error.middleware';
import { CreateUserDto, UpdateUserDto } from '../types/user.types';
import prisma from '../config/database';

export const getAllUsers = async () => {
  return await prisma.user.findMany({
    orderBy: {
      createdAt: 'desc'
    }
  });
};

export const getUserById = async (id: string) => {
  const user = await prisma.user.findUnique({
    where: { id }
  });

  if (!user) {
    throw new AppError('User not found', 404);
  }

  return user;
};

export const createUser = async (data: CreateUserDto) => {
  // Check if email already exists
  const existingUser = await prisma.user.findUnique({
    where: { email: data.email }
  });

  if (existingUser) {
    throw new AppError('Email already exists', 400);
  }

  return await prisma.user.create({
    data: {
      email: data.email,
      name: data.name || ''
    }
  });
};

export const updateUser = async (id: string, data: UpdateUserDto) => {
  // Check if user exists
  const user = await prisma.user.findUnique({
    where: { id }
  });

  if (!user) {
    throw new AppError('User not found', 404);
  }

  // Check if email is being updated and if it already exists
  if (data.email && data.email !== user.email) {
    const existingUser = await prisma.user.findUnique({
      where: { email: data.email }
    });

    if (existingUser) {
      throw new AppError('Email already exists', 400);
    }
  }

  return await prisma.user.update({
    where: { id },
    data
  });
};

export const deleteUser = async (id: string): Promise<void> => {
  // Check if user exists
  const user = await prisma.user.findUnique({
    where: { id }
  });

  if (!user) {
    throw new AppError('User not found', 404);
  }

  await prisma.user.delete({
    where: { id }
  });
};
